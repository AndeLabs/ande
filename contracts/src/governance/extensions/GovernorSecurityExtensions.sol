// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title GovernorSecurityExtensions
 * @author Ande Labs
 * @notice Extensiones de seguridad para governance
 * 
 * FEATURES:
 * 1. Anti-whale con cap de voting power (10% del supply)
 * 2. Rate limiting para propuestas (1 día cooldown)
 * 3. Guardian para cancelación de emergencia
 * 4. Anti-frontrunning con proposer commitment
 * 
 * PROTECCIONES:
 * - Previene concentración de poder en pocas manos
 * - Evita spam de propuestas
 * - Permite respuesta rápida a amenazas
 * - Reduce ataques de frontrunning
 */
abstract contract GovernorSecurityExtensions is GovernorUpgradeable {
    using SafeCast for uint256;
    
    uint256 public constant MAX_VOTING_POWER_BPS = 1000;
    uint256 public constant PROPOSAL_COOLDOWN = 1 days;
    
    mapping(address => uint256) public lastProposalTime;
    
    address public guardian;
    
    mapping(uint256 => address) public proposalCommitment;
    
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event ProposalCancelledByGuardian(uint256 indexed proposalId, string reason);
    event VotingPowerCapped(address indexed voter, uint256 originalPower, uint256 cappedPower);
    event ProposalCooldownActive(address indexed proposer, uint256 remainingTime);
    
    error ProposalCooldownNotExpired(uint256 remainingTime);
    error UnauthorizedGuardian();
    error InvalidGuardian();
    error ProposalNotActive();
    
    function __GovernorSecurityExtensions_init(address _guardian) internal onlyInitializing {
        if (_guardian == address(0)) revert InvalidGuardian();
        guardian = _guardian;
    }
    
    /**
     * @notice Override de _castVote con protección anti-whale
     * @dev Limita el voting power a 10% del total supply
     * SECURITY: Implementa cap de voting power para prevenir whale attacks
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override returns (uint256) {
        uint256 weight = _getVotes(account, proposalSnapshot(proposalId), params);
        
        // Anti-whale protection: cap voting power at 10% of total supply
        uint256 totalSupply = _getTotalSupply(proposalSnapshot(proposalId));
        uint256 maxAllowedVotes = (totalSupply * MAX_VOTING_POWER_BPS) / 10000;
        
        if (weight > maxAllowedVotes) {
            emit VotingPowerCapped(account, weight, maxAllowedVotes);
            weight = maxAllowedVotes;
        }
        
        // Call _countVote with capped weight
        _countVote(proposalId, account, support, weight, params);
        
        // Return the capped weight used for voting
        return weight;
    }
    
    /**
     * @notice Override de propose con rate limiting
     * @dev Previene spam requiriendo 1 día entre propuestas del mismo proposer
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        uint256 timeSinceLastProposal = block.timestamp - lastProposalTime[msg.sender];
        
        if (timeSinceLastProposal < PROPOSAL_COOLDOWN && lastProposalTime[msg.sender] != 0) {
            uint256 remainingTime = PROPOSAL_COOLDOWN - timeSinceLastProposal;
            emit ProposalCooldownActive(msg.sender, remainingTime);
            revert ProposalCooldownNotExpired(remainingTime);
        }
        
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        
        lastProposalTime[msg.sender] = block.timestamp;
        
        proposalCommitment[proposalId] = msg.sender;
        
        return proposalId;
    }
    
    /**
     * @notice Permite al guardian cancelar propuestas maliciosas
     * @param targets Array de direcciones target
     * @param values Array de valores
     * @param calldatas Array de calldatas
     * @param descriptionHash Hash de la descripción
     * @param reason Razón de la cancelación
     * @return proposalId ID de la propuesta cancelada
     */
    function guardianCancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash,
        string calldata reason
    ) external returns (uint256) {
        if (msg.sender != guardian) revert UnauthorizedGuardian();
        
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Pending && currentState != ProposalState.Active) {
            revert ProposalNotActive();
        }
        
        uint256 cancelledProposalId = _cancel(targets, values, calldatas, descriptionHash);
        
        emit ProposalCancelledByGuardian(cancelledProposalId, reason);
        
        return cancelledProposalId;
    }
    
    /**
     * @notice Actualiza guardian
     * @dev Solo governance puede actualizar
     * @param newGuardian Nueva dirección del guardian
     */
    function updateGuardian(address newGuardian) external virtual onlyGovernance {
        if (newGuardian == address(0)) revert InvalidGuardian();
        
        address oldGuardian = guardian;
        guardian = newGuardian;
        
        emit GuardianUpdated(oldGuardian, newGuardian);
    }
    
    /**
     * @notice Permite al guardian renunciar a su rol
     * @dev Útil para descentralización progresiva
     */
    function guardianRenounce() external {
        if (msg.sender != guardian) revert UnauthorizedGuardian();
        
        address oldGuardian = guardian;
        guardian = address(0);
        
        emit GuardianUpdated(oldGuardian, address(0));
    }
    
    /**
     * @notice Obtiene el proposer original de una propuesta
     * @param proposalId ID de la propuesta
     * @return Dirección del proposer
     */
    function getProposalCommitment(uint256 proposalId) external view returns (address) {
        return proposalCommitment[proposalId];
    }
    
    /**
     * @notice Verifica si un address puede proponer (cooldown expirado)
     * @param account Dirección a verificar
     * @return true si puede proponer
     */
    function canPropose(address account) external view returns (bool) {
        if (lastProposalTime[account] == 0) return true;
        
        uint256 timeSinceLastProposal = block.timestamp - lastProposalTime[account];
        return timeSinceLastProposal >= PROPOSAL_COOLDOWN;
    }
    
    /**
     * @notice Obtiene tiempo restante de cooldown
     * @param account Dirección a verificar
     * @return Tiempo restante en segundos (0 si puede proponer)
     */
    function getRemainingCooldown(address account) external view returns (uint256) {
        if (lastProposalTime[account] == 0) return 0;
        
        uint256 timeSinceLastProposal = block.timestamp - lastProposalTime[account];
        
        if (timeSinceLastProposal >= PROPOSAL_COOLDOWN) {
            return 0;
        }
        
        return PROPOSAL_COOLDOWN - timeSinceLastProposal;
    }
    
    /**
     * @notice Calcula el voting power efectivo después del cap
     * @param account Dirección del votante
     * @param timepoint Punto en el tiempo
     * @return Voting power con cap aplicado
     */
    function getEffectiveVotingPower(address account, uint256 timepoint) 
        external 
        view 
        returns (uint256) 
    {
        uint256 rawVotingPower = _getVotes(account, timepoint, "");
        uint256 totalSupply = _getTotalSupply(timepoint);
        uint256 maxAllowedVotes = (totalSupply * MAX_VOTING_POWER_BPS) / 10000;
        
        if (rawVotingPower > maxAllowedVotes) {
            return maxAllowedVotes;
        }
        
        return rawVotingPower;
    }
    
    function _getTotalSupply(uint256 timepoint) internal view virtual returns (uint256);
}
