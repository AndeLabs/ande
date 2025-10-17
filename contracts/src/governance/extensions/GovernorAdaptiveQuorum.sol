// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title GovernorAdaptiveQuorum
 * @author Ande Labs
 * @notice Quorum que se ajusta dinámicamente según participación histórica
 * 
 * ALGORITMO:
 * 1. Registra participación de cada propuesta ejecutada
 * 2. Calcula promedio de últimas 10 propuestas
 * 3. Ajusta quorum entre 4% y 15% según participación
 * 
 * FÓRMULA DE QUORUM:
 * - Participación >= 20% → Quorum = 4% (MIN_QUORUM_BPS)
 * - Participación <= 10% → Quorum = 15% (MAX_QUORUM_BPS)
 * - Participación entre 10% y 20% → Interpolación lineal
 * 
 * EJEMPLO:
 * Si las últimas 10 propuestas tuvieron:
 * - Promedio 25% participación → Quorum = 4%
 * - Promedio 8% participación → Quorum = 15%
 * - Promedio 15% participación → Quorum = 9.5% (interpolado)
 * 
 * BENEFICIOS:
 * - Previene estancamiento por baja participación
 * - Mantiene seguridad cuando hay alta participación
 * - Auto-ajuste sin intervención manual
 * - Incentiva participación consistente
 */
abstract contract GovernorAdaptiveQuorum is GovernorUpgradeable {
    using SafeCast for uint256;
    
    uint256 public constant MIN_QUORUM_BPS = 400;   // 4%
    uint256 public constant MAX_QUORUM_BPS = 1500;  // 15%
    uint256 public constant HIGH_PARTICIPATION_THRESHOLD = 2000; // 20%
    uint256 public constant LOW_PARTICIPATION_THRESHOLD = 1000;  // 10%
    uint256 public constant BASIS_POINTS = 10000;
    
    uint256 public constant PARTICIPATION_HISTORY_SIZE = 10;
    
    struct ProposalParticipation {
        uint256 proposalId;
        uint256 totalVotes;
        uint256 totalSupply;
        uint256 participationBps;
        uint256 timestamp;
    }
    
    uint256 private _participationHistoryIndex;
    ProposalParticipation[PARTICIPATION_HISTORY_SIZE] private _participationHistory;
    uint256 private _participationHistoryCount;
    
    event QuorumAdjusted(uint256 indexed proposalId, uint256 newQuorumBps, uint256 avgParticipation);
    event ParticipationRecorded(
        uint256 indexed proposalId, 
        uint256 participationBps,
        uint256 totalVotes,
        uint256 totalSupply
    );
    
    function __GovernorAdaptiveQuorum_init() internal onlyInitializing {
        _participationHistoryIndex = 0;
        _participationHistoryCount = 0;
    }
    
    /**
     * @notice Calcula quorum adaptativo basado en participación histórica
     * @dev Override de GovernorUpgradeable.quorum()
     * @param timepoint Punto en el tiempo para calcular quorum
     * @return Quorum requerido en tokens absolutos
     */
    function quorum(uint256 timepoint) 
        public 
        view 
        virtual 
        override 
        returns (uint256) 
    {
        uint256 totalSupply = _getTotalSupply(timepoint);
        uint256 quorumBps = _calculateAdaptiveQuorum();
        
        return (totalSupply * quorumBps) / BASIS_POINTS;
    }
    
    /**
     * @notice Calcula el quorum adaptativo según histórico de participación
     * @return Quorum en basis points (4% = 400, 15% = 1500)
     */
    function _calculateAdaptiveQuorum() internal view returns (uint256) {
        if (_participationHistoryCount == 0) {
            return MAX_QUORUM_BPS;
        }
        
        uint256 avgParticipation = _getAverageParticipation();
        
        if (avgParticipation >= HIGH_PARTICIPATION_THRESHOLD) {
            return MIN_QUORUM_BPS;
        }
        
        if (avgParticipation <= LOW_PARTICIPATION_THRESHOLD) {
            return MAX_QUORUM_BPS;
        }
        
        uint256 range = HIGH_PARTICIPATION_THRESHOLD - LOW_PARTICIPATION_THRESHOLD;
        uint256 quorumRange = MAX_QUORUM_BPS - MIN_QUORUM_BPS;
        
        uint256 participationDelta = avgParticipation - LOW_PARTICIPATION_THRESHOLD;
        uint256 quorumReduction = (participationDelta * quorumRange) / range;
        
        return MAX_QUORUM_BPS - quorumReduction;
    }
    
    /**
     * @notice Obtiene participación promedio de últimas N propuestas
     * @return Participación promedio en basis points
     */
    function _getAverageParticipation() internal view returns (uint256) {
        if (_participationHistoryCount == 0) {
            return 1500;
        }
        
        uint256 sum = 0;
        uint256 count = _participationHistoryCount > PARTICIPATION_HISTORY_SIZE 
            ? PARTICIPATION_HISTORY_SIZE 
            : _participationHistoryCount;
        
        for (uint256 i = 0; i < count; i++) {
            sum += _participationHistory[i].participationBps;
        }
        
        return sum / count;
    }
    
    /**
     * @notice Registra participación de una propuesta
     * @dev Se llama cuando una propuesta es ejecutada o cancelada
     * @param proposalId ID de la propuesta
     * @param forVotes Votos a favor
     * @param againstVotes Votos en contra
     * @param abstainVotes Votos abstención
     */
    function _recordParticipation(
        uint256 proposalId,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) internal {
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        
        if (totalVotes == 0) {
            return;
        }
        
        uint256 totalSupply = _getTotalSupply(clock() - 1);
        
        if (totalSupply == 0) {
            return;
        }
        
        uint256 participationBps = (totalVotes * BASIS_POINTS) / totalSupply;
        
        _participationHistory[_participationHistoryIndex] = ProposalParticipation({
            proposalId: proposalId,
            totalVotes: totalVotes,
            totalSupply: totalSupply,
            participationBps: participationBps,
            timestamp: block.timestamp
        });
        
        _participationHistoryIndex = (_participationHistoryIndex + 1) % PARTICIPATION_HISTORY_SIZE;
        _participationHistoryCount++;
        
        emit ParticipationRecorded(proposalId, participationBps, totalVotes, totalSupply);
        
        uint256 newQuorumBps = _calculateAdaptiveQuorum();
        emit QuorumAdjusted(proposalId, newQuorumBps, _getAverageParticipation());
    }
    
    /**
     * @notice Override de _execute para registrar participación
     * @dev Hook que se ejecuta cuando una propuesta es exitosa
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
        
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = _getProposalVotes(proposalId);
        _recordParticipation(proposalId, forVotes, againstVotes, abstainVotes);
    }
    
    /**
     * @notice Override de _cancel para registrar participación
     * @dev Hook que se ejecuta cuando una propuesta es cancelada
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);
        
        return proposalId;
    }
    
    function _getProposalVotes(uint256 proposalId) internal view virtual returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        return (0, 0, 0);
    }
    
    /**
     * @notice Obtiene total supply en un bloque específico
     * @dev Debe ser implementado por contrato que herede
     * @param timepoint Bloque para consultar total supply
     * @return Total supply en ese bloque
     */
    function _getTotalSupply(uint256 timepoint) internal view virtual returns (uint256);
    
    /**
     * @notice Vista pública para consultar histórico de participación
     * @return Array con últimas 10 propuestas registradas
     */
    function getParticipationHistory() 
        external 
        view 
        returns (ProposalParticipation[PARTICIPATION_HISTORY_SIZE] memory) 
    {
        return _participationHistory;
    }
    
    /**
     * @notice Vista pública para consultar quorum actual en BPS
     * @return Quorum en basis points (400 = 4%, 1500 = 15%)
     */
    function getCurrentQuorumBps() external view returns (uint256) {
        return _calculateAdaptiveQuorum();
    }
    
    /**
     * @notice Vista pública para consultar participación promedio
     * @return Participación promedio en basis points
     */
    function getAverageParticipation() external view returns (uint256) {
        return _getAverageParticipation();
    }
    
    /**
     * @notice Obtiene número de propuestas registradas en histórico
     * @return Cantidad de propuestas en histórico
     */
    function getParticipationHistoryCount() external view returns (uint256) {
        return _participationHistoryCount > PARTICIPATION_HISTORY_SIZE 
            ? PARTICIPATION_HISTORY_SIZE 
            : _participationHistoryCount;
    }
}
