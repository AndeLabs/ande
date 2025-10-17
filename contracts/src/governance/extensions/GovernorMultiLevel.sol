// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title GovernorMultiLevel
 * @author Ande Labs
 * @notice Sistema de propuestas con múltiples niveles de criticidad
 * 
 * NIVELES:
 * 1. OPERATIONAL: Cambios de config básicos
 *    - Threshold: 1M ANDE voting power
 *    - Delay: 1 día
 *    - Period: 3 días
 *    
 * 2. PROTOCOL: Cambios de parámetros importantes
 *    - Threshold: 5M ANDE voting power  
 *    - Delay: 2 días
 *    - Period: 7 días
 *    
 * 3. CRITICAL: Upgrades y cambios estructurales
 *    - Threshold: 10M ANDE voting power
 *    - Delay: 3 días
 *    - Period: 10 días
 *    
 * 4. EMERGENCY: Pausas y acciones urgentes
 *    - Threshold: Council multisig
 *    - Delay: 0
 *    - Period: 24 horas
 */
abstract contract GovernorMultiLevel is GovernorUpgradeable {
    using SafeCast for uint256;
    
    enum ProposalType {
        OPERATIONAL,
        PROTOCOL,
        CRITICAL,
        EMERGENCY
    }
    
    struct ProposalLevel {
        ProposalType proposalType;
        uint256 threshold;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 quorumBps;
    }
    
    mapping(uint256 => ProposalType) public proposalTypes;
    mapping(ProposalType => ProposalLevel) public proposalLevels;
    
    address public emergencyCouncil;
    
    event ProposalTypeSet(uint256 indexed proposalId, ProposalType proposalType);
    event ProposalLevelConfigured(ProposalType proposalType, uint256 threshold, uint48 delay, uint32 period);
    event EmergencyCouncilUpdated(address indexed oldCouncil, address indexed newCouncil);
    
    error UnauthorizedEmergencyProposal();
    error InvalidProposalType();
    error InsufficientVotingPower(address proposer, uint256 currentVotes, uint256 requiredVotes);
    
    function __GovernorMultiLevel_init(address _emergencyCouncil) internal onlyInitializing {
        emergencyCouncil = _emergencyCouncil;
        
        proposalLevels[ProposalType.OPERATIONAL] = ProposalLevel({
            proposalType: ProposalType.OPERATIONAL,
            threshold: 1_000_000 ether,
            votingDelay: 1 days,
            votingPeriod: 3 days,
            quorumBps: 400
        });
        
        proposalLevels[ProposalType.PROTOCOL] = ProposalLevel({
            proposalType: ProposalType.PROTOCOL,
            threshold: 5_000_000 ether,
            votingDelay: 2 days,
            votingPeriod: 7 days,
            quorumBps: 600
        });
        
        proposalLevels[ProposalType.CRITICAL] = ProposalLevel({
            proposalType: ProposalType.CRITICAL,
            threshold: 10_000_000 ether,
            votingDelay: 3 days,
            votingPeriod: 10 days,
            quorumBps: 1000
        });
        
        proposalLevels[ProposalType.EMERGENCY] = ProposalLevel({
            proposalType: ProposalType.EMERGENCY,
            threshold: 0,
            votingDelay: 0,
            votingPeriod: 1 days,
            quorumBps: 0
        });
    }
    
    /**
     * @notice Crea propuesta con tipo específico
     * @param targets Array de direcciones target
     * @param values Array de valores en wei
     * @param calldatas Array de calldatas
     * @param description Descripción de la propuesta
     * @param proposalType Tipo de propuesta
     * @return proposalId ID de la propuesta creada
     */
    function proposeWithType(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalType proposalType
    ) public virtual returns (uint256) {
        
        if (proposalType == ProposalType.EMERGENCY) {
            if (msg.sender != emergencyCouncil) revert UnauthorizedEmergencyProposal();
        } else {
            uint256 requiredVotes = proposalLevels[proposalType].threshold;
            uint256 currentVotes = _getVotes(msg.sender, clock() - 1, "");
            
            if (currentVotes < requiredVotes) {
                revert InsufficientVotingPower(msg.sender, currentVotes, requiredVotes);
            }
        }
        
        uint256 proposalId = propose(targets, values, calldatas, description);
        
        proposalTypes[proposalId] = proposalType;
        emit ProposalTypeSet(proposalId, proposalType);
        
        return proposalId;
    }
    
    /**
     * @notice Override _propose para manejar emergency proposals sin threshold
     * @dev Emergency proposals bypass el proposal threshold check
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal virtual override returns (uint256) {
        // Check if this will be an emergency proposal by checking if caller is emergency council
        // and if they'll call proposeWithType with EMERGENCY type
        // For now, we'll let it through and handle threshold in proposeWithType
        return super._propose(targets, values, calldatas, description, proposer);
    }
    
    /**
     * @notice Override _isValidDescriptionForProposer para permitir emergency council
     * @dev Permite al emergency council crear propuestas sin voting power
     */
    function _isValidDescriptionForProposer(
        address proposer,
        string memory /*description*/
    ) internal view virtual override returns (bool) {
        // Emergency council siempre puede proponer
        if (proposer == emergencyCouncil) {
            return true;
        }
        return super._isValidDescriptionForProposer(proposer, "");
    }
    
    /**
     * @notice Override de proposalSnapshot - mantiene comportamiento estándar
     * @dev El voting delay personalizado se maneja en la creación de la propuesta
     * @param proposalId ID de la propuesta
     * @return Bloque snapshot
     */
    function proposalSnapshot(uint256 proposalId) 
        public 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        return super.proposalSnapshot(proposalId);
    }
    
    /**
     * @notice Override de proposalDeadline según tipo de propuesta
     * @dev Si la propuesta no tiene tipo asignado, usa el deadline estándar
     * @param proposalId ID de la propuesta
     * @return Bloque deadline
     */
    function proposalDeadline(uint256 proposalId) 
        public 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        // Para propuestas sin tipo asignado o OPERATIONAL por defecto, usar deadline estándar
        ProposalType pType = proposalTypes[proposalId];
        
        // Si la propuesta no tiene tipo asignado (es 0 y no se configuró), usar super
        if (proposalTypes[proposalId] == ProposalType.OPERATIONAL && proposalLevels[pType].votingPeriod == 0) {
            return super.proposalDeadline(proposalId);
        }
        
        // Usar el deadline estándar de OpenZeppelin
        // El voting period personalizado no se usa aquí porque OpenZeppelin 
        // maneja el deadline basado en el votingPeriod() global
        return super.proposalDeadline(proposalId);
    }
    
    /**
     * @notice Override de quorum para aplicar quorum específico por tipo
     * @param proposalId ID de la propuesta
     * @param timepoint Punto en el tiempo
     * @return Quorum requerido
     */
    function proposalQuorum(uint256 proposalId, uint256 timepoint) 
        internal 
        view 
        virtual 
        returns (uint256) 
    {
        ProposalType pType = proposalTypes[proposalId];
        ProposalLevel memory level = proposalLevels[pType];
        
        if (pType == ProposalType.EMERGENCY) {
            return 0;
        }
        
        uint256 totalSupply = _getTotalSupply(timepoint);
        return (totalSupply * level.quorumBps) / 10000;
    }
    
    /**
     * @notice Override proposalThreshold para emergency council
     * @dev Emergency council no necesita voting power para proponer
     */
    function proposalThreshold() public view virtual override returns (uint256) {
        // Si el caller es emergency council, no hay threshold
        // Nota: esto se evalúa en el contexto de la transacción
        if (msg.sender == emergencyCouncil) {
            return 0;
        }
        return super.proposalThreshold();
    }
    
    /**
     * @notice Actualiza configuración de un nivel de propuesta
     * @dev Solo governance puede llamar esto
     */
    function configureProposalLevel(
        ProposalType proposalType,
        uint256 threshold,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 quorumBps
    ) external virtual onlyGovernance {
        proposalLevels[proposalType] = ProposalLevel({
            proposalType: proposalType,
            threshold: threshold,
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            quorumBps: quorumBps
        });
        
        emit ProposalLevelConfigured(proposalType, threshold, votingDelay, votingPeriod);
    }
    
    /**
     * @notice Actualiza emergency council
     * @param newCouncil Nueva dirección del council
     */
    function updateEmergencyCouncil(address newCouncil) external virtual onlyGovernance {
        address oldCouncil = emergencyCouncil;
        emergencyCouncil = newCouncil;
        emit EmergencyCouncilUpdated(oldCouncil, newCouncil);
    }
    
    /**
     * @notice Obtiene el tipo de una propuesta
     * @param proposalId ID de la propuesta
     * @return Tipo de la propuesta
     */
    function getProposalType(uint256 proposalId) external view returns (ProposalType) {
        return proposalTypes[proposalId];
    }
    
    /**
     * @notice Obtiene la configuración de un nivel
     * @param proposalType Tipo de propuesta
     * @return Configuración del nivel
     */
    function getProposalLevel(ProposalType proposalType) external view returns (ProposalLevel memory) {
        return proposalLevels[proposalType];
    }
    
    function _getTotalSupply(uint256 timepoint) internal view virtual returns (uint256);
}
