// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// MessageHashUtils not available in v4.9.0, using ECDSA.toEthSignedMessageHash instead

/**
 * @title AndeConsensus
 * @author Ande Labs
 * @notice Contrato central de consenso PoS que coordina sequencers/validators
 * @dev Implementa selección de proposer estilo CometBFT con weighted round-robin
 *
 * ARQUITECTURA:
 * - Validator Set: Lista de validadores activos con voting power
 * - Proposer Selection: Weighted round-robin determinístico (CometBFT-style)
 * - Attestations: Sistema de firmas BFT (2/3+1 para finalidad)
 * - Slashing: Penalización por mala conducta (doble firma, downtime)
 * - Epochs: Períodos de 90 días para cambios de validator set
 *
 * PROPOSER SELECTION ALGORITHM (CometBFT):
 * 1. Cada validator tiene un "accumulated priority" (A)
 * 2. Cada bloque: A(i) += VP(i) para todos los validators
 * 3. Proposer = validator con mayor A
 * 4. A(proposer) -= TotalVotingPower
 * 5. Resultado: Frecuencia de selección proporcional al voting power
 *
 * EJEMPLO:
 * Validator A: VP=100, Validator B: VP=300
 * Total VP = 400
 * En 400 bloques: A seleccionado 100 veces, B seleccionado 300 veces
 *
 * INTEGRACION CON EV-RETH:
 * - Events ValidatorSetUpdated, BlockProposed son escuchados por ev-reth
 * - ev-reth mantiene sincronizado el validator set local
 * - ev-reth verifica firmas antes de aceptar bloques
 */
contract AndeConsensus is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;
    // using MessageHashUtils for bytes32; // Not available in v4.9.0

    // ============================================
    // ROLES
    // ============================================
    
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant VALIDATOR_MANAGER_ROLE = keccak256("VALIDATOR_MANAGER_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    // ============================================
    // STRUCTS
    // ============================================

    /**
     * @notice Información completa de un validator
     * @dev Compatible con consensus_client.rs ValidatorInfo
     */
    struct ValidatorInfo {
        address validator;           // Address del validator
        bytes32 p2pPeerId;          // libp2p peer ID para networking
        string rpcEndpoint;         // RPC endpoint del nodo
        uint256 stake;              // Cantidad de ANDE staked
        uint256 power;              // Voting power (stake + bonuses)
        int256 accumulatedPriority; // Priority acumulado (CometBFT algorithm)
        uint256 totalBlocksProduced;// Total de bloques producidos
        uint256 totalBlocksMissed; // Total de bloques perdidos
        uint256 uptime;             // Uptime en basis points (10000 = 100%)
        uint256 lastBlockProduced;  // Timestamp del último bloque
        uint256 registeredAt;       // Timestamp de registro
        bool jailed;                // Si está encarcelado (temporalmente inactivo)
        bool active;                // Si está activo
        bool isPermanent;           // Si es validator permanente (Genesis)
    }

    /**
     * @notice Propuesta de bloque
     */
    struct BlockProposal {
        uint256 blockNumber;        // Número de bloque
        bytes32 blockHash;          // Hash del bloque
        address producer;           // Address del productor
        bytes signature;            // Firma del productor
        uint256 timestamp;          // Timestamp de la propuesta
        bool verified;              // Si fue verificado
    }

    /**
     * @notice Atestación de un validator sobre un bloque
     */
    struct Attestation {
        address validator;          // Validator que atestigua
        bytes32 blockHash;          // Hash del bloque
        bytes signature;            // Firma del validator
        uint256 timestamp;          // Timestamp de la atestación
    }

    /**
     * @notice Información de época
     */
    struct EpochInfo {
        uint256 epochNumber;        // Número de época
        uint256 startBlock;         // Bloque de inicio
        uint256 endBlock;           // Bloque de fin
        uint256 startTime;          // Timestamp de inicio
        uint256 endTime;            // Timestamp de fin
        address[] validators;       // Validators activos en esta época
        uint256 totalVotingPower;   // Total voting power de la época
    }

    // ============================================
    // CONSTANTS
    // ============================================

    /// @notice Duración de una época en bloques (aproximadamente 90 días con 2s block time)
    uint256 public constant EPOCH_DURATION_BLOCKS = 3_888_000;

    /// @notice Mínimo uptime requerido en basis points (9900 = 99%)
    uint256 public constant MIN_UPTIME_BPS = 9900;

    /// @notice Basis points para porcentajes (10000 = 100%)
    uint256 public constant BASIS_POINTS = 10000;

    /// @notice Máximo voting power permitido (para evitar overflow en priority)
    int256 public constant MAX_TOTAL_VOTING_POWER = type(int64).max / 8;

    /// @notice Threshold BFT: 2/3 + 1 de voting power para finalidad
    uint256 public constant BFT_THRESHOLD_NUMERATOR = 2;
    uint256 public constant BFT_THRESHOLD_DENOMINATOR = 3;

    /// @notice Penalty por doble firma (50% del stake)
    uint256 public constant DOUBLE_SIGN_SLASH_BPS = 5000;

    /// @notice Penalty por downtime (5% del stake)
    uint256 public constant DOWNTIME_SLASH_BPS = 500;

    /// @notice Bloques de gracia antes de jailing por downtime
    uint256 public constant DOWNTIME_JAIL_BLOCKS = 1000;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Epoch actual
    uint256 public currentEpoch;

    /// @notice Bloque actual del chain
    uint256 public currentBlockNumber;

    /// @notice Total voting power de todos los validators activos
    uint256 public totalVotingPower;

    /// @notice Mapping de validator address a su información
    mapping(address => ValidatorInfo) public validators;

    /// @notice Lista de addresses de validators activos
    address[] public activeValidators;

    /// @notice Mapping de epoch a su información
    mapping(uint256 => EpochInfo) public epochs;

    /// @notice Mapping de blockNumber a su propuesta
    mapping(uint256 => BlockProposal) public blockProposals;

    /// @notice Mapping de blockHash a lista de atestaciones
    mapping(bytes32 => Attestation[]) public attestations;

    /// @notice Mapping de blockHash a total voting power que lo atestiguó
    mapping(bytes32 => uint256) public attestationPower;

    /// @notice Proposer actual (cache)
    address public currentProposer;

    /// @notice Índice del proposer en activeValidators array
    uint256 private proposerIndex;

    /// @notice Contador de bloques sin propuesta válida
    uint256 public missedBlocks;

    /// @notice Referencia al contrato de staking
    address public stakingContract;

    /// @notice Referencia al contrato de sequencer registry
    address public sequencerRegistry;

    // ============================================
    // EVENTS
    // ============================================

    event ValidatorSetUpdated(
        uint256 indexed epoch,
        address[] validators,
        uint256[] powers,
        uint256 totalPower
    );

    event BlockProposed(
        uint256 indexed blockNumber,
        bytes32 indexed blockHash,
        address indexed producer,
        uint256 timestamp
    );

    event BlockAttested(
        uint256 indexed blockNumber,
        bytes32 indexed blockHash,
        address indexed validator,
        uint256 totalPower
    );

    event BlockFinalized(
        uint256 indexed blockNumber,
        bytes32 indexed blockHash,
        uint256 totalPower,
        uint256 threshold
    );

    event ProposerSelected(
        uint256 indexed blockNumber,
        address indexed proposer,
        int256 priority
    );

    event ValidatorJailed(
        address indexed validator,
        string reason,
        uint256 timestamp
    );

    event ValidatorUnjailed(
        address indexed validator,
        uint256 timestamp
    );

    event ValidatorSlashed(
        address indexed validator,
        uint256 amount,
        string reason,
        uint256 timestamp
    );

    event EpochStarted(
        uint256 indexed epoch,
        uint256 startBlock,
        uint256 startTime,
        address[] validators
    );

    event EpochEnded(
        uint256 indexed epoch,
        uint256 endBlock,
        uint256 endTime
    );

    // ============================================
    // ERRORS
    // ============================================

    error ValidatorNotFound(address validator);
    error ValidatorNotActive(address validator);
    error ValidatorIsJailed(address validator);
    error InvalidSignature();
    error BlockAlreadyProposed(uint256 blockNumber);
    error NotDesignatedProposer(address expected, address actual);
    error InsufficientVotingPower(uint256 have, uint256 need);
    error EpochNotEnded();
    error InvalidBlockNumber(uint256 expected, uint256 actual);
    error DoubleSign(address validator, uint256 blockNumber);
    error InvalidVotingPower();

    // ============================================
    // CONSTRUCTOR & INITIALIZER
    // ============================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa el contrato
     * @param defaultAdmin Address con rol de admin
     * @param _stakingContract Address del contrato de staking
     * @param _sequencerRegistry Address del registro de sequencers
     * @param genesisValidator Primer validator (Foundation)
     * @param genesisP2pPeerId libp2p peer ID del genesis validator
     * @param genesisRpcEndpoint RPC endpoint del genesis validator
     */
    function initialize(
        address defaultAdmin,
        address _stakingContract,
        address _sequencerRegistry,
        address genesisValidator,
        bytes32 genesisP2pPeerId,
        string calldata genesisRpcEndpoint
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(VALIDATOR_MANAGER_ROLE, defaultAdmin);
        _grantRole(SLASHER_ROLE, defaultAdmin);

        stakingContract = _stakingContract;
        sequencerRegistry = _sequencerRegistry;

        currentEpoch = 1;
        currentBlockNumber = 0;

        // Registrar genesis validator
        _registerGenesisValidator(
            genesisValidator,
            genesisP2pPeerId,
            genesisRpcEndpoint
        );

        // Iniciar primera época
        _startEpoch();
    }

    // ============================================
    // VALIDATOR MANAGEMENT
    // ============================================

    /**
     * @notice Registra el genesis validator (Foundation)
     */
    function _registerGenesisValidator(
        address validator,
        bytes32 p2pPeerId,
        string memory rpcEndpoint
    ) internal {
        ValidatorInfo storage val = validators[validator];
        val.validator = validator;
        val.p2pPeerId = p2pPeerId;
        val.rpcEndpoint = rpcEndpoint;
        val.stake = 0; // Genesis no requiere stake
        val.power = 100; // Voting power inicial
        val.accumulatedPriority = 0;
        val.registeredAt = block.timestamp;
        val.active = true;
        val.isPermanent = true;

        activeValidators.push(validator);
        totalVotingPower = 100;
        currentProposer = validator;
    }

    /**
     * @notice Registra un nuevo validator
     * @dev Solo VALIDATOR_MANAGER_ROLE puede llamar
     */
    function registerValidator(
        address validator,
        bytes32 p2pPeerId,
        string calldata rpcEndpoint,
        uint256 stake,
        uint256 power
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) whenNotPaused {
        if (validators[validator].validator != address(0)) {
            revert ValidatorNotFound(validator);
        }

        if (power == 0 || power > uint256(uint64(type(int64).max))) {
            revert InvalidVotingPower();
        }

        ValidatorInfo storage val = validators[validator];
        val.validator = validator;
        val.p2pPeerId = p2pPeerId;
        val.rpcEndpoint = rpcEndpoint;
        val.stake = stake;
        val.power = power;
        val.accumulatedPriority = 0;
        val.registeredAt = block.timestamp;
        val.active = true;
        val.isPermanent = false;

        activeValidators.push(validator);
        totalVotingPower += power;

        // Recalcular proposer
        _updateProposer();
    }

    /**
     * @notice Actualiza el voting power de un validator
     */
    function updateValidatorPower(
        address validator,
        uint256 newPower
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) whenNotPaused {
        ValidatorInfo storage val = validators[validator];
        if (val.validator == address(0)) revert ValidatorNotFound(validator);
        if (!val.active) revert ValidatorNotActive(validator);

        if (newPower == 0 || newPower > uint256(uint64(type(int64).max))) {
            revert InvalidVotingPower();
        }

        totalVotingPower = totalVotingPower - val.power + newPower;
        val.power = newPower;

        _updateProposer();
    }

    /**
     * @notice Desactiva un validator
     */
    function deactivateValidator(
        address validator
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        ValidatorInfo storage val = validators[validator];
        if (val.validator == address(0)) revert ValidatorNotFound(validator);
        if (val.isPermanent) revert ValidatorNotActive(validator);

        val.active = false;
        totalVotingPower -= val.power;

        // Remover de activeValidators
        for (uint256 i = 0; i < activeValidators.length; i++) {
            if (activeValidators[i] == validator) {
                activeValidators[i] = activeValidators[activeValidators.length - 1];
                activeValidators.pop();
                break;
            }
        }

        _updateProposer();
    }

    // ============================================
    // PROPOSER SELECTION (CometBFT Algorithm)
    // ============================================

    /**
     * @notice Selecciona el próximo proposer usando weighted round-robin
     * @dev Implementación del algoritmo CometBFT
     * @return address del validator seleccionado como proposer
     */
    function _selectProposer() internal returns (address) {
        if (activeValidators.length == 0) {
            return address(0);
        }

        if (activeValidators.length == 1) {
            return activeValidators[0];
        }

        // CometBFT Algorithm:
        // 1. Incrementar priority de todos los validators por su voting power
        // 2. Seleccionar validator con mayor priority
        // 3. Decrementar priority del seleccionado por total voting power

        int256 maxPriority = type(int256).min;
        address proposer = address(0);
        uint256 proposerIdx = 0;

        // Paso 1 & 2: Incrementar priorities y encontrar máximo
        for (uint256 i = 0; i < activeValidators.length; i++) {
            address val = activeValidators[i];
            ValidatorInfo storage valInfo = validators[val];

            if (!valInfo.active || valInfo.jailed) continue;

            // Incrementar priority por voting power
            valInfo.accumulatedPriority += int256(valInfo.power);

            // Encontrar máximo
            if (valInfo.accumulatedPriority > maxPriority) {
                maxPriority = valInfo.accumulatedPriority;
                proposer = val;
                proposerIdx = i;
            }
        }

        if (proposer == address(0)) {
            return address(0);
        }

        // Paso 3: Decrementar priority del proposer
        validators[proposer].accumulatedPriority -= int256(totalVotingPower);

        // Actualizar state
        currentProposer = proposer;
        proposerIndex = proposerIdx;

        emit ProposerSelected(currentBlockNumber + 1, proposer, maxPriority);

        return proposer;
    }

    /**
     * @notice Obtiene el proposer designado para un bloque
     * @dev Para uso por ev-reth
     */
    function getBlockProducer(uint256 blockNumber) external view returns (address) {
        if (blockNumber == currentBlockNumber + 1) {
            return currentProposer;
        }
        
        // Para bloques futuros, necesitaríamos simular el algoritmo
        // Por ahora retornamos el proposer actual
        return currentProposer;
    }

    /**
     * @notice Actualiza el proposer (llamado después de cambios en validator set)
     */
    function _updateProposer() internal {
        _selectProposer();
    }

    // ============================================
    // BLOCK PRODUCTION & ATTESTATION
    // ============================================

    /**
     * @notice Propone un nuevo bloque
     * @param blockNumber Número del bloque
     * @param blockHash Hash del bloque
     * @param signature Firma del productor
     */
    function proposeBlock(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
        // Validar que es el bloque esperado
        if (blockNumber != currentBlockNumber + 1) {
            revert InvalidBlockNumber(currentBlockNumber + 1, blockNumber);
        }

        // Validar que no existe propuesta para este bloque
        if (blockProposals[blockNumber].producer != address(0)) {
            revert BlockAlreadyProposed(blockNumber);
        }

        // Validar que el caller es el proposer designado
        if (msg.sender != currentProposer) {
            revert NotDesignatedProposer(currentProposer, msg.sender);
        }

        ValidatorInfo storage val = validators[msg.sender];
        if (!val.active) revert ValidatorNotActive(msg.sender);
        if (val.jailed) revert ValidatorIsJailed(msg.sender);

        // Verificar firma
        bytes32 messageHash = keccak256(abi.encodePacked(blockNumber, blockHash));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);
        
        if (signer != msg.sender) {
            revert InvalidSignature();
        }

        // Guardar propuesta
        blockProposals[blockNumber] = BlockProposal({
            blockNumber: blockNumber,
            blockHash: blockHash,
            producer: msg.sender,
            signature: signature,
            timestamp: block.timestamp,
            verified: true
        });

        // Actualizar estadísticas del validator
        val.totalBlocksProduced++;
        val.lastBlockProduced = block.timestamp;

        // Actualizar block number
        currentBlockNumber = blockNumber;

        // Seleccionar próximo proposer
        _selectProposer();

        emit BlockProposed(blockNumber, blockHash, msg.sender, block.timestamp);
    }

    /**
     * @notice Atestigua un bloque
     * @param blockNumber Número del bloque
     * @param blockHash Hash del bloque
     * @param signature Firma del validator
     */
    function attestBlock(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes calldata signature
    ) external whenNotPaused {
        ValidatorInfo storage val = validators[msg.sender];
        if (!val.active) revert ValidatorNotActive(msg.sender);
        if (val.jailed) revert ValidatorIsJailed(msg.sender);

        // Verificar firma
        bytes32 messageHash = keccak256(abi.encodePacked(blockNumber, blockHash));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);
        
        if (signer != msg.sender) {
            revert InvalidSignature();
        }

        // Guardar atestación
        attestations[blockHash].push(Attestation({
            validator: msg.sender,
            blockHash: blockHash,
            signature: signature,
            timestamp: block.timestamp
        }));

        // Incrementar voting power total
        attestationPower[blockHash] += val.power;

        emit BlockAttested(blockNumber, blockHash, msg.sender, attestationPower[blockHash]);

        // Check si alcanzamos threshold BFT (2/3 + 1)
        uint256 threshold = (totalVotingPower * BFT_THRESHOLD_NUMERATOR) / BFT_THRESHOLD_DENOMINATOR + 1;
        if (attestationPower[blockHash] >= threshold) {
            emit BlockFinalized(blockNumber, blockHash, attestationPower[blockHash], threshold);
        }
    }

    /**
     * @notice Verifica si un bloque está finalizado (tiene 2/3+1 attestations)
     */
    function isBlockFinalized(bytes32 blockHash) external view returns (bool) {
        uint256 threshold = (totalVotingPower * BFT_THRESHOLD_NUMERATOR) / BFT_THRESHOLD_DENOMINATOR + 1;
        return attestationPower[blockHash] >= threshold;
    }

    // ============================================
    // SLASHING & JAILING
    // ============================================

    /**
     * @notice Slash a un validator por doble firma
     */
    function slashDoubleSign(
        address validator,
        uint256 blockNumber,
        bytes32 blockHash1,
        bytes calldata signature1,
        bytes32 blockHash2,
        bytes calldata signature2
    ) external onlyRole(SLASHER_ROLE) {
        ValidatorInfo storage val = validators[validator];
        if (val.validator == address(0)) revert ValidatorNotFound(validator);

        // Verificar que ambas firmas son válidas y para el mismo bloque
        bytes32 message1 = keccak256(abi.encodePacked(blockNumber, blockHash1));
        bytes32 message2 = keccak256(abi.encodePacked(blockNumber, blockHash2));
        
        if (blockHash1 == blockHash2) {
            revert InvalidSignature();
        }

        address signer1 = message1.toEthSignedMessageHash().recover(signature1);
        address signer2 = message2.toEthSignedMessageHash().recover(signature2);

        if (signer1 != validator || signer2 != validator) {
            revert InvalidSignature();
        }

        // Calcular penalty (50% del stake)
        uint256 slashAmount = (val.stake * DOUBLE_SIGN_SLASH_BPS) / BASIS_POINTS;

        // Aplicar slash
        val.stake -= slashAmount;
        val.jailed = true;
        val.active = false;

        emit ValidatorSlashed(validator, slashAmount, "Double sign", block.timestamp);
        emit ValidatorJailed(validator, "Double sign", block.timestamp);
    }

    /**
     * @notice Slash a un validator por downtime
     */
    function slashDowntime(
        address validator
    ) external onlyRole(SLASHER_ROLE) {
        ValidatorInfo storage val = validators[validator];
        if (val.validator == address(0)) revert ValidatorNotFound(validator);

        // Verificar que el uptime está por debajo del mínimo
        if (val.uptime >= MIN_UPTIME_BPS) {
            revert InsufficientVotingPower(val.uptime, MIN_UPTIME_BPS);
        }

        // Calcular penalty (5% del stake)
        uint256 slashAmount = (val.stake * DOWNTIME_SLASH_BPS) / BASIS_POINTS;

        // Aplicar slash
        val.stake -= slashAmount;
        val.jailed = true;
        val.active = false;

        emit ValidatorSlashed(validator, slashAmount, "Downtime", block.timestamp);
        emit ValidatorJailed(validator, "Downtime", block.timestamp);
    }

    /**
     * @notice Unjail a un validator
     */
    function unjailValidator(
        address validator
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        ValidatorInfo storage val = validators[validator];
        if (val.validator == address(0)) revert ValidatorNotFound(validator);
        if (!val.jailed) return;

        val.jailed = false;
        val.active = true;

        emit ValidatorUnjailed(validator, block.timestamp);
    }

    // ============================================
    // EPOCH MANAGEMENT
    // ============================================

    /**
     * @notice Inicia una nueva época
     */
    function _startEpoch() internal {
        EpochInfo storage epoch = epochs[currentEpoch];
        epoch.epochNumber = currentEpoch;
        epoch.startBlock = currentBlockNumber;
        epoch.startTime = block.timestamp;
        epoch.validators = activeValidators;
        epoch.totalVotingPower = totalVotingPower;

        emit EpochStarted(currentEpoch, currentBlockNumber, block.timestamp, activeValidators);
    }

    /**
     * @notice Finaliza época actual e inicia la siguiente
     */
    function advanceEpoch() external onlyRole(VALIDATOR_MANAGER_ROLE) {
        EpochInfo storage epoch = epochs[currentEpoch];
        
        if (currentBlockNumber < epoch.startBlock + EPOCH_DURATION_BLOCKS) {
            revert EpochNotEnded();
        }

        epoch.endBlock = currentBlockNumber;
        epoch.endTime = block.timestamp;

        emit EpochEnded(currentEpoch, currentBlockNumber, block.timestamp);

        currentEpoch++;
        _startEpoch();

        // Emitir evento para ev-reth
        uint256[] memory powers = new uint256[](activeValidators.length);
        for (uint256 i = 0; i < activeValidators.length; i++) {
            powers[i] = validators[activeValidators[i]].power;
        }

        emit ValidatorSetUpdated(currentEpoch, activeValidators, powers, totalVotingPower);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory) {
        return validators[validator];
    }

    function getActiveValidators() external view returns (address[] memory) {
        return activeValidators;
    }

    function getActiveValidatorsCount() external view returns (uint256) {
        return activeValidators.length;
    }

    function getCurrentProposer() external view returns (address) {
        return currentProposer;
    }

    function getEpochInfo(uint256 epoch) external view returns (EpochInfo memory) {
        return epochs[epoch];
    }

    function getBlockProposal(uint256 blockNumber) external view returns (BlockProposal memory) {
        return blockProposals[blockNumber];
    }

    function getAttestations(bytes32 blockHash) external view returns (Attestation[] memory) {
        return attestations[blockHash];
    }

    function getAttestationPower(bytes32 blockHash) external view returns (uint256) {
        return attestationPower[blockHash];
    }

    function isValidator(address addr) external view returns (bool) {
        return validators[addr].validator != address(0) && validators[addr].active;
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

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