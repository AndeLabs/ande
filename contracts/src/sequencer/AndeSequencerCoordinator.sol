// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AndeSequencerCoordinator
 * @author Ande Labs
 * @notice Coordinador descentralizado de sequencers con rotación round-robin y timeout
 * @dev Sistema completo de gestión, rotación automática, slashing y timeout
 *
 * CARACTERÍSTICAS:
 * ✅ Round-Robin: Rotación automática cada N bloques
 * ✅ Timeout: Forzar rotación si sequencer no produce bloques
 * ✅ Slashing: Penalizar sequencers maliciosos o inactivos
 * ✅ Health Monitoring: Tracking on-chain de performance
 * ✅ Force Inclusion: Usuarios pueden forzar inclusión de TXs
 * ✅ Emergency Fallback: Sistema de backup automático
 */
contract AndeSequencerCoordinator is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SEQUENCER_MANAGER_ROLE = keccak256("SEQUENCER_MANAGER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // ============================================
    // CONSTANTS
    // ============================================
    uint256 public constant MIN_STAKE_AMOUNT = 100_000 * 1e18; // 100k ANDE
    uint256 public constant BLOCKS_PER_ROTATION = 100; // Rotar cada 100 bloques
    uint256 public constant TIMEOUT_BLOCKS = 10; // Timeout después de 10 bloques sin producir
    uint256 public constant SLASH_PERCENTAGE_TIMEOUT = 1000; // 10% por timeout
    uint256 public constant SLASH_PERCENTAGE_INVALID = 5000; // 50% por bloque inválido
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_UPTIME_PERCENTAGE = 9900; // 99% uptime requerido
    uint256 public constant FORCE_INCLUSION_TIMEOUT = 50; // 50 bloques para force inclusion

    // ============================================
    // STRUCTS
    // ============================================
    struct SequencerInfo {
        address sequencerAddress;
        uint256 stakedAmount;
        uint256 registeredAt;
        uint256 lastBlockProduced;
        uint256 lastBlockNumber;
        uint256 totalBlocksProduced;
        uint256 totalTimeouts;
        uint256 totalSlashes;
        uint256 uptimePercentage;
        bool isActive;
        bool isJailed;
        uint256 jailEndTime;
        string endpoint; // RPC endpoint del sequencer
        bytes32 nodeId; // Node ID para P2P
    }

    struct RotationInfo {
        uint256 rotationNumber;
        uint256 startBlock;
        uint256 endBlock;
        address leader;
        uint256 blocksProduced;
        uint256 missedBlocks;
        bool completedSuccessfully;
    }

    struct ForceInclusionRequest {
        address requester;
        bytes32 txHash;
        uint256 requestedAt;
        bool included;
    }

    // ============================================
    // STATE VARIABLES
    // ============================================
    IERC20 public andeToken;

    // Sequencer management
    mapping(address => SequencerInfo) public sequencers;
    address[] public sequencerList;
    address[] public activeSequencers;

    // Rotation management
    uint256 public currentRotationNumber;
    uint256 public currentLeaderIndex;
    address public currentLeader;
    uint256 public lastRotationBlock;
    mapping(uint256 => RotationInfo) public rotations;

    // Timeout tracking
    mapping(address => uint256) public lastHeartbeat;
    uint256 public lastBlockNumber;

    // Force inclusion
    mapping(bytes32 => ForceInclusionRequest) public forceInclusionRequests;
    bytes32[] public pendingForceInclusions;

    // Emergency fallback
    address public emergencySequencer;
    bool public emergencyMode;

    // ============================================
    // EVENTS
    // ============================================
    event SequencerRegistered(
        address indexed sequencer, uint256 stakedAmount, string endpoint, bytes32 nodeId
    );
    event SequencerUnregistered(address indexed sequencer, uint256 returnedStake);
    event SequencerSlashed(
        address indexed sequencer, uint256 amount, string reason, uint256 newStake
    );
    event SequencerJailed(address indexed sequencer, uint256 jailEndTime, string reason);
    event SequencerUnjailed(address indexed sequencer);

    event LeaderRotated(
        uint256 indexed rotationNumber,
        address indexed oldLeader,
        address indexed newLeader,
        uint256 blockNumber,
        string reason
    );
    event BlockProduced(
        address indexed sequencer, uint256 blockNumber, uint256 timestamp, uint256 gasUsed
    );
    event TimeoutDetected(
        address indexed sequencer, uint256 missedBlocks, uint256 slashedAmount
    );
    event InvalidBlockDetected(address indexed sequencer, uint256 blockNumber, string reason);

    event ForceInclusionRequested(
        bytes32 indexed txHash, address indexed requester, uint256 requestBlock
    );
    event ForceInclusionCompleted(bytes32 indexed txHash, uint256 includedAtBlock);

    event EmergencyModeActivated(address indexed emergencySequencer, string reason);
    event EmergencyModeDeactivated();

    event UptimeUpdated(address indexed sequencer, uint256 uptimePercentage);

    // ============================================
    // ERRORS
    // ============================================
    error InsufficientStake();
    error SequencerAlreadyRegistered();
    error SequencerNotFound();
    error SequencerNotActive();
    error SequencerIsJailed();
    error NotCurrentLeader();
    error RotationNotDue();
    error TimeoutNotReached();
    error InvalidBlockNumber();
    error EmergencyModeActive();
    error NoActiveSequencers();
    error ForceInclusionNotDue();

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address _andeToken,
        address _emergencySequencer
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(SEQUENCER_MANAGER_ROLE, defaultAdmin);
        _grantRole(ORACLE_ROLE, defaultAdmin);

        andeToken = IERC20(_andeToken);
        emergencySequencer = _emergencySequencer;
        emergencyMode = false;

        currentRotationNumber = 1;
        currentLeaderIndex = 0;
        lastRotationBlock = block.number;
    }

    // ============================================
    // SEQUENCER REGISTRATION
    // ============================================

    /**
     * @notice Registrar nuevo sequencer con stake
     * @param stakedAmount Cantidad de ANDE a stakear
     * @param endpoint RPC endpoint del sequencer
     * @param nodeId Node ID para comunicación P2P
     */
    function registerSequencer(uint256 stakedAmount, string calldata endpoint, bytes32 nodeId)
        external
        whenNotPaused
        nonReentrant
    {
        if (sequencers[msg.sender].sequencerAddress != address(0)) {
            revert SequencerAlreadyRegistered();
        }
        if (stakedAmount < MIN_STAKE_AMOUNT) revert InsufficientStake();

        // Transferir stake
        require(
            andeToken.transferFrom(msg.sender, address(this), stakedAmount),
            "Stake transfer failed"
        );

        // Registrar sequencer
        sequencers[msg.sender] = SequencerInfo({
            sequencerAddress: msg.sender,
            stakedAmount: stakedAmount,
            registeredAt: block.timestamp,
            lastBlockProduced: block.timestamp,
            lastBlockNumber: block.number,
            totalBlocksProduced: 0,
            totalTimeouts: 0,
            totalSlashes: 0,
            uptimePercentage: 10000, // 100% inicial
            isActive: true,
            isJailed: false,
            jailEndTime: 0,
            endpoint: endpoint,
            nodeId: nodeId
        });

        sequencerList.push(msg.sender);
        activeSequencers.push(msg.sender);
        lastHeartbeat[msg.sender] = block.timestamp;

        // Si es el primer sequencer, hacerlo líder
        if (activeSequencers.length == 1) {
            currentLeader = msg.sender;
            _startRotation(msg.sender);
        }

        emit SequencerRegistered(msg.sender, stakedAmount, endpoint, nodeId);
    }

    /**
     * @notice Dejar de ser sequencer y recuperar stake
     */
    function unregisterSequencer() external nonReentrant {
        SequencerInfo storage seq = sequencers[msg.sender];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();
        if (seq.isJailed) revert SequencerIsJailed();

        uint256 stakeToReturn = seq.stakedAmount;

        // Desactivar
        seq.isActive = false;

        // Remover de lista activa
        _removeFromActiveList(msg.sender);

        // Rotar líder si era el actual
        if (currentLeader == msg.sender && activeSequencers.length > 0) {
            _forceRotation("Leader unregistered");
        }

        // Devolver stake
        require(andeToken.transfer(msg.sender, stakeToReturn), "Stake return failed");

        emit SequencerUnregistered(msg.sender, stakeToReturn);
    }

    /**
     * @notice Aumentar stake de sequencer
     */
    function increaseStake(uint256 amount) external nonReentrant {
        SequencerInfo storage seq = sequencers[msg.sender];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();

        require(andeToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        seq.stakedAmount += amount;
    }

    // ============================================
    // BLOCK PRODUCTION & ROTATION
    // ============================================

    /**
     * @notice Registrar que un bloque fue producido por el sequencer actual
     * @param sequencer Dirección del sequencer que produjo el bloque
     * @param blockNumber Número de bloque
     * @param gasUsed Gas usado en el bloque
     */
    function recordBlockProduced(address sequencer, uint256 blockNumber, uint256 gasUsed)
        external
        onlyRole(ORACLE_ROLE)
        whenNotPaused
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();
        if (!seq.isActive) revert SequencerNotActive();

        // Verificar que sea el líder actual
        if (sequencer != currentLeader && !emergencyMode) revert NotCurrentLeader();

        // Actualizar info del sequencer
        seq.lastBlockProduced = block.timestamp;
        seq.lastBlockNumber = blockNumber;
        seq.totalBlocksProduced++;
        lastHeartbeat[sequencer] = block.timestamp;
        lastBlockNumber = blockNumber;

        // Actualizar rotación actual
        RotationInfo storage rotation = rotations[currentRotationNumber];
        rotation.blocksProduced++;

        emit BlockProduced(sequencer, blockNumber, block.timestamp, gasUsed);

        // Verificar si es momento de rotar
        if (
            block.number >= lastRotationBlock + BLOCKS_PER_ROTATION
                && activeSequencers.length > 1
        ) {
            _rotateLeader();
        }
    }

    /**
     * @notice Rotación automática al siguiente sequencer (round-robin)
     */
    function _rotateLeader() internal {
        if (activeSequencers.length == 0) revert NoActiveSequencers();

        // Completar rotación actual
        RotationInfo storage currentRotation = rotations[currentRotationNumber];
        currentRotation.endBlock = block.number;
        currentRotation.completedSuccessfully = true;

        // Calcular missed blocks
        uint256 expectedBlocks = currentRotation.endBlock - currentRotation.startBlock;
        currentRotation.missedBlocks = expectedBlocks > currentRotation.blocksProduced
            ? expectedBlocks - currentRotation.blocksProduced
            : 0;

        address oldLeader = currentLeader;

        // Round-robin: siguiente en la lista
        currentLeaderIndex = (currentLeaderIndex + 1) % activeSequencers.length;
        address newLeader = activeSequencers[currentLeaderIndex];

        // Verificar que el nuevo líder no esté en jail
        while (sequencers[newLeader].isJailed && activeSequencers.length > 1) {
            currentLeaderIndex = (currentLeaderIndex + 1) % activeSequencers.length;
            newLeader = activeSequencers[currentLeaderIndex];
        }

        currentLeader = newLeader;
        lastRotationBlock = block.number;
        currentRotationNumber++;

        _startRotation(newLeader);

        emit LeaderRotated(currentRotationNumber, oldLeader, newLeader, block.number, "Round-robin");
    }

    function _startRotation(address leader) internal {
        rotations[currentRotationNumber] = RotationInfo({
            rotationNumber: currentRotationNumber,
            startBlock: block.number,
            endBlock: 0,
            leader: leader,
            blocksProduced: 0,
            missedBlocks: 0,
            completedSuccessfully: false
        });
    }

    /**
     * @notice Forzar rotación manualmente (admin o por timeout)
     */
    function forceRotation(string calldata reason) external onlyRole(SEQUENCER_MANAGER_ROLE) {
        _forceRotation(reason);
    }

    function _forceRotation(string memory reason) internal {
        if (activeSequencers.length == 0) revert NoActiveSequencers();

        address oldLeader = currentLeader;

        // Marcar rotación actual como fallida
        RotationInfo storage currentRotation = rotations[currentRotationNumber];
        currentRotation.endBlock = block.number;
        currentRotation.completedSuccessfully = false;

        // Siguiente líder
        currentLeaderIndex = (currentLeaderIndex + 1) % activeSequencers.length;
        currentLeader = activeSequencers[currentLeaderIndex];
        lastRotationBlock = block.number;
        currentRotationNumber++;

        _startRotation(currentLeader);

        emit LeaderRotated(currentRotationNumber, oldLeader, currentLeader, block.number, reason);
    }

    // ============================================
    // TIMEOUT MECHANISM
    // ============================================

    /**
     * @notice Detectar timeout: Si líder no produce bloques por N bloques
     * @dev Cualquiera puede llamar esta función para verificar timeout
     */
    function checkTimeout() external {
        if (activeSequencers.length == 0) revert NoActiveSequencers();

        SequencerInfo storage leader = sequencers[currentLeader];

        // Verificar si pasó el timeout
        uint256 blocksSinceLastBlock = block.number - leader.lastBlockNumber;

        if (blocksSinceLastBlock < TIMEOUT_BLOCKS) revert TimeoutNotReached();

        // TIMEOUT DETECTADO - Aplicar penalización

        // 1. Slash por timeout
        uint256 slashAmount = (leader.stakedAmount * SLASH_PERCENTAGE_TIMEOUT) / BASIS_POINTS;
        leader.stakedAmount -= slashAmount;
        leader.totalTimeouts++;
        leader.totalSlashes++;

        emit TimeoutDetected(currentLeader, blocksSinceLastBlock, slashAmount);
        emit SequencerSlashed(
            currentLeader, slashAmount, "Timeout - no blocks produced", leader.stakedAmount
        );

        // 2. Jail si es reincidente (3+ timeouts)
        if (leader.totalTimeouts >= 3) {
            _jailSequencer(currentLeader, "Multiple timeouts");
        }

        // 3. Forzar rotación
        _forceRotation("Timeout detected");
    }

    /**
     * @notice Enviar heartbeat para demostrar que sequencer está vivo
     */
    function heartbeat() external {
        SequencerInfo storage seq = sequencers[msg.sender];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();
        if (!seq.isActive) revert SequencerNotActive();

        lastHeartbeat[msg.sender] = block.timestamp;
    }

    // ============================================
    // SLASHING
    // ============================================

    /**
     * @notice Slash sequencer por bloque inválido o comportamiento malicioso
     */
    function slashSequencer(address sequencer, uint256 amount, string calldata reason)
        external
        onlyRole(SEQUENCER_MANAGER_ROLE)
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();

        uint256 actualSlash = amount > seq.stakedAmount ? seq.stakedAmount : amount;

        seq.stakedAmount -= actualSlash;
        seq.totalSlashes++;

        emit SequencerSlashed(sequencer, actualSlash, reason, seq.stakedAmount);

        // Si stake cae por debajo del mínimo, jail automático
        if (seq.stakedAmount < MIN_STAKE_AMOUNT) {
            _jailSequencer(sequencer, "Stake below minimum");
        }
    }

    /**
     * @notice Reportar bloque inválido producido por sequencer
     */
    function reportInvalidBlock(address sequencer, uint256 blockNumber, string calldata reason)
        external
        onlyRole(ORACLE_ROLE)
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();

        // Slash severo por bloque inválido (50%)
        uint256 slashAmount = (seq.stakedAmount * SLASH_PERCENTAGE_INVALID) / BASIS_POINTS;
        seq.stakedAmount -= slashAmount;
        seq.totalSlashes++;

        emit InvalidBlockDetected(sequencer, blockNumber, reason);
        emit SequencerSlashed(
            sequencer, slashAmount, "Invalid block produced", seq.stakedAmount
        );

        // Jail inmediato
        _jailSequencer(sequencer, "Invalid block");

        // Si era el líder, rotar
        if (sequencer == currentLeader) {
            _forceRotation("Leader produced invalid block");
        }
    }

    // ============================================
    // JAILING
    // ============================================

    function _jailSequencer(address sequencer, string memory reason) internal {
        SequencerInfo storage seq = sequencers[sequencer];

        seq.isJailed = true;
        seq.jailEndTime = block.timestamp + 7 days; // 7 días de jail

        // Remover de lista activa
        _removeFromActiveList(sequencer);

        emit SequencerJailed(sequencer, seq.jailEndTime, reason);
    }

    /**
     * @notice Liberar sequencer de jail después del tiempo
     */
    function unjailSequencer(address sequencer) external {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();
        if (!seq.isJailed) revert("Not jailed");
        if (block.timestamp < seq.jailEndTime) revert("Jail period not ended");

        // Verificar que tenga stake suficiente
        if (seq.stakedAmount < MIN_STAKE_AMOUNT) revert InsufficientStake();

        seq.isJailed = false;
        seq.jailEndTime = 0;
        seq.isActive = true;

        activeSequencers.push(sequencer);

        emit SequencerUnjailed(sequencer);
    }

    // ============================================
    // FORCE INCLUSION
    // ============================================

    /**
     * @notice Usuario puede forzar inclusión de TX si sequencers censoran
     * @param txHash Hash de la transacción
     */
    function requestForceInclusion(bytes32 txHash) external {
        if (forceInclusionRequests[txHash].requestedAt != 0) {
            revert("Already requested");
        }

        forceInclusionRequests[txHash] = ForceInclusionRequest({
            requester: msg.sender,
            txHash: txHash,
            requestedAt: block.number,
            included: false
        });

        pendingForceInclusions.push(txHash);

        emit ForceInclusionRequested(txHash, msg.sender, block.number);
    }

    /**
     * @notice Marcar TX como incluida (llamado por oracle)
     */
    function markForceInclusionCompleted(bytes32 txHash, uint256 includedAtBlock)
        external
        onlyRole(ORACLE_ROLE)
    {
        ForceInclusionRequest storage request = forceInclusionRequests[txHash];
        if (request.requestedAt == 0) revert("Request not found");

        request.included = true;

        // Remover de pending
        for (uint256 i = 0; i < pendingForceInclusions.length; i++) {
            if (pendingForceInclusions[i] == txHash) {
                pendingForceInclusions[i] = pendingForceInclusions[pendingForceInclusions.length - 1];
                pendingForceInclusions.pop();
                break;
            }
        }

        emit ForceInclusionCompleted(txHash, includedAtBlock);
    }

    /**
     * @notice Verificar si hay TXs pendientes de force inclusion que pasaron timeout
     * @dev Slash al líder si no incluyó después del timeout
     */
    function checkForceInclusionTimeout() external {
        for (uint256 i = 0; i < pendingForceInclusions.length; i++) {
            bytes32 txHash = pendingForceInclusions[i];
            ForceInclusionRequest storage request = forceInclusionRequests[txHash];

            if (
                !request.included
                    && block.number >= request.requestedAt + FORCE_INCLUSION_TIMEOUT
            ) {
                // Slash al líder actual por censura
                SequencerInfo storage leader = sequencers[currentLeader];
                uint256 slashAmount = (leader.stakedAmount * 500) / BASIS_POINTS; // 5%

                leader.stakedAmount -= slashAmount;
                leader.totalSlashes++;

                emit SequencerSlashed(
                    currentLeader, slashAmount, "Censorship - force inclusion timeout", leader.stakedAmount
                );

                // Forzar rotación
                _forceRotation("Force inclusion timeout");
            }
        }
    }

    // ============================================
    // EMERGENCY MODE
    // ============================================

    function activateEmergencyMode(string calldata reason)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencyMode = true;
        currentLeader = emergencySequencer;

        emit EmergencyModeActivated(emergencySequencer, reason);
    }

    function deactivateEmergencyMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyMode = false;

        // Restaurar líder normal
        if (activeSequencers.length > 0) {
            currentLeader = activeSequencers[currentLeaderIndex];
        }

        emit EmergencyModeDeactivated();
    }

    // ============================================
    // UPTIME TRACKING
    // ============================================

    function updateSequencerUptime(address sequencer, uint256 uptimePercentage)
        external
        onlyRole(ORACLE_ROLE)
    {
        SequencerInfo storage seq = sequencers[sequencer];
        if (seq.sequencerAddress == address(0)) revert SequencerNotFound();

        seq.uptimePercentage = uptimePercentage;

        emit UptimeUpdated(sequencer, uptimePercentage);

        // Si uptime muy bajo, jail
        if (uptimePercentage < MIN_UPTIME_PERCENTAGE && !seq.isJailed) {
            _jailSequencer(sequencer, "Low uptime");
        }
    }

    // ============================================
    // HELPERS
    // ============================================

    function _removeFromActiveList(address sequencer) internal {
        for (uint256 i = 0; i < activeSequencers.length; i++) {
            if (activeSequencers[i] == sequencer) {
                activeSequencers[i] = activeSequencers[activeSequencers.length - 1];
                activeSequencers.pop();

                // Ajustar índice si es necesario
                if (i <= currentLeaderIndex && currentLeaderIndex > 0) {
                    currentLeaderIndex--;
                }
                break;
            }
        }
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    function getActiveSequencers() external view returns (address[] memory) {
        return activeSequencers;
    }

    function getSequencerInfo(address sequencer)
        external
        view
        returns (SequencerInfo memory)
    {
        return sequencers[sequencer];
    }

    function getCurrentRotation() external view returns (RotationInfo memory) {
        return rotations[currentRotationNumber];
    }

    function getRotationInfo(uint256 rotationNumber)
        external
        view
        returns (RotationInfo memory)
    {
        return rotations[rotationNumber];
    }

    function isTimeoutReached() external view returns (bool) {
        if (activeSequencers.length == 0) return false;

        SequencerInfo storage leader = sequencers[currentLeader];
        uint256 blocksSinceLastBlock = block.number - leader.lastBlockNumber;

        return blocksSinceLastBlock >= TIMEOUT_BLOCKS;
    }

    function getPendingForceInclusions() external view returns (bytes32[] memory) {
        return pendingForceInclusions;
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    function setBlocksPerRotation(uint256 newBlocks) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Note: This would require updating the constant or making it a state variable
        // For now, it's a constant defined at compile time
    }

    function setEmergencySequencer(address newEmergencySequencer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emergencySequencer = newEmergencySequencer;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
