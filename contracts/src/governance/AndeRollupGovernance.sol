// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IAndeSequencerRegistry {
    function addSequencer(address sequencer, uint256 stake) external;
    function removeSequencer(address sequencer) external;
    function updateSequencerStake(address sequencer, uint256 newStake) external;
}

/**
 * @title AndeRollupGovernance
 * @author Ande Labs
 * @notice Governance específica para parámetros del rollup soberano
 * 
 * CAPABILITIES:
 * - Gestión de sequencers
 * - Configuración de fees del rollup
 * - Parámetros de Celestia DA
 * - Actualización de precompiles
 * - Configuración de gas fees
 * 
 * SECURITY:
 * - Solo governance puede modificar parámetros críticos
 * - Emergency role para pausas rápidas
 * - Límites de seguridad en todos los parámetros
 */
contract AndeRollupGovernance is 
    Initializable, 
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    IAndeSequencerRegistry public sequencerRegistry;
    
    uint256 public baseFeePerGas;
    uint256 public priorityFeePerGas;
    uint256 public sequencerCutBps;
    
    uint256 public celestiaDAFee;
    bytes29 public celestiaNamespace;
    
    uint256 public constant MAX_BASE_FEE = 1000 gwei;
    uint256 public constant MAX_PRIORITY_FEE = 100 gwei;
    uint256 public constant MAX_SEQUENCER_CUT_BPS = 5000;
    uint256 public constant BASIS_POINTS = 10000;
    
    bool public paused;
    
    event BaseFeeUpdated(uint256 oldFee, uint256 newFee);
    event PriorityFeeUpdated(uint256 oldFee, uint256 newFee);
    event SequencerCutUpdated(uint256 oldCut, uint256 newCut);
    event SequencerRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event CelestiaDAFeeUpdated(uint256 oldFee, uint256 newFee);
    event CelestiaNamespaceUpdated(bytes29 oldNamespace, bytes29 newNamespace);
    event SequencerAdded(address indexed sequencer, uint256 stake);
    event SequencerRemoved(address indexed sequencer);
    event EmergencyPaused(address indexed pauser);
    event EmergencyUnpaused(address indexed unpauser);
    
    error FeeExceedsMaximum();
    error InvalidBasisPoints();
    error ZeroAddress();
    error RollupPaused();
    error RollupNotPaused();
    error InvalidSequencerStake();
    
    modifier whenNotPaused() {
        if (paused) revert RollupPaused();
        _;
    }
    
    modifier whenPaused() {
        if (!paused) revert RollupNotPaused();
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initializes the contract
     * @param _sequencerRegistry Address of the sequencer registry
     * @param governor Address of the governor contract
     */
    function initialize(
        address _sequencerRegistry,
        address governor
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        if (_sequencerRegistry == address(0) || governor == address(0)) {
            revert ZeroAddress();
        }
        
        sequencerRegistry = IAndeSequencerRegistry(_sequencerRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
        
        baseFeePerGas = 1 gwei;
        priorityFeePerGas = 1 gwei;
        sequencerCutBps = 4000;
        celestiaDAFee = 0.01 ether;
        paused = false;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
    
    /**
     * @notice Actualiza base fee del gas
     * @param newBaseFee Nueva base fee
     */
    function updateBaseFee(uint256 newBaseFee) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        if (newBaseFee > MAX_BASE_FEE) revert FeeExceedsMaximum();
        
        uint256 oldFee = baseFeePerGas;
        baseFeePerGas = newBaseFee;
        
        emit BaseFeeUpdated(oldFee, newBaseFee);
    }
    
    /**
     * @notice Actualiza priority fee
     * @param newPriorityFee Nueva priority fee
     */
    function updatePriorityFee(uint256 newPriorityFee) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        if (newPriorityFee > MAX_PRIORITY_FEE) revert FeeExceedsMaximum();
        
        uint256 oldFee = priorityFeePerGas;
        priorityFeePerGas = newPriorityFee;
        
        emit PriorityFeeUpdated(oldFee, newPriorityFee);
    }
    
    /**
     * @notice Actualiza % de fees que va a sequencers
     * @param newCutBps Nuevo porcentaje en basis points
     */
    function updateSequencerCut(uint256 newCutBps) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        if (newCutBps > MAX_SEQUENCER_CUT_BPS) revert InvalidBasisPoints();
        
        uint256 oldCut = sequencerCutBps;
        sequencerCutBps = newCutBps;
        
        emit SequencerCutUpdated(oldCut, newCutBps);
    }
    
    /**
     * @notice Agrega nuevo sequencer
     * @param newSequencer Dirección del nuevo sequencer
     * @param stake Cantidad de ANDE a stakear
     */
    function addSequencer(address newSequencer, uint256 stake) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        if (newSequencer == address(0)) revert ZeroAddress();
        if (stake < 100_000 ether) revert InvalidSequencerStake();
        
        sequencerRegistry.addSequencer(newSequencer, stake);
        
        emit SequencerAdded(newSequencer, stake);
    }
    
    /**
     * @notice Remueve sequencer
     * @param sequencer Dirección del sequencer a remover
     */
    function removeSequencer(address sequencer) 
        external 
        onlyRole(GOVERNOR_ROLE)
    {
        sequencerRegistry.removeSequencer(sequencer);
        
        emit SequencerRemoved(sequencer);
    }
    
    /**
     * @notice Actualiza stake de un sequencer
     * @param sequencer Dirección del sequencer
     * @param newStake Nuevo stake
     */
    function updateSequencerStake(address sequencer, uint256 newStake)
        external
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        if (newStake < 100_000 ether) revert InvalidSequencerStake();
        
        sequencerRegistry.updateSequencerStake(sequencer, newStake);
    }
    
    /**
     * @notice Actualiza fees de Celestia DA
     * @param newFee Nuevo fee
     */
    function updateCelestiaDAFee(uint256 newFee) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        uint256 oldFee = celestiaDAFee;
        celestiaDAFee = newFee;
        
        emit CelestiaDAFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @notice Actualiza namespace de Celestia
     * @param newNamespace Nuevo namespace
     */
    function updateCelestiaNamespace(bytes29 newNamespace) 
        external 
        onlyRole(GOVERNOR_ROLE)
        whenNotPaused
    {
        bytes29 oldNamespace = celestiaNamespace;
        celestiaNamespace = newNamespace;
        
        emit CelestiaNamespaceUpdated(oldNamespace, newNamespace);
    }
    
    /**
     * @notice Actualiza sequencer registry
     * @param newRegistry Nueva dirección del registry
     */
    function updateSequencerRegistry(address newRegistry)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        if (newRegistry == address(0)) revert ZeroAddress();
        
        address oldRegistry = address(sequencerRegistry);
        sequencerRegistry = IAndeSequencerRegistry(newRegistry);
        
        emit SequencerRegistryUpdated(oldRegistry, newRegistry);
    }
    
    /**
     * @notice Pausa el rollup en caso de emergencia
     */
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) whenNotPaused {
        paused = true;
        emit EmergencyPaused(msg.sender);
    }
    
    /**
     * @notice Despausa el rollup
     */
    function emergencyUnpause() external onlyRole(EMERGENCY_ROLE) whenPaused {
        paused = false;
        emit EmergencyUnpaused(msg.sender);
    }
    
    /**
     * @notice Calcula el fee total para una transacción
     * @param gasUsed Gas utilizado
     * @return Total fee
     */
    function calculateTotalFee(uint256 gasUsed) external view returns (uint256) {
        return (baseFeePerGas + priorityFeePerGas) * gasUsed;
    }
    
    /**
     * @notice Calcula el corte del sequencer de un fee
     * @param totalFee Fee total
     * @return Fee para el sequencer
     */
    function calculateSequencerCut(uint256 totalFee) external view returns (uint256) {
        return (totalFee * sequencerCutBps) / BASIS_POINTS;
    }
    
    /**
     * @notice Obtiene parámetros actuales del rollup
     * @return baseFee Base fee actual
     * @return priorityFee Priority fee actual
     * @return sequencerCut Sequencer cut en BPS
     * @return celestiaFee Celestia DA fee
     * @return isPaused Estado de pausa
     */
    function getRollupParameters() 
        external 
        view 
        returns (
            uint256 baseFee,
            uint256 priorityFee,
            uint256 sequencerCut,
            uint256 celestiaFee,
            bool isPaused
        ) 
    {
        return (
            baseFeePerGas,
            priorityFeePerGas,
            sequencerCutBps,
            celestiaDAFee,
            paused
        );
    }
}
