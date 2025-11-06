// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface IAndeNativeStaking {
    struct StakeInfo {
        uint256 amount;
        uint8 level;
        uint8 lockPeriod;
        uint256 lockUntil;
        uint256 votingPower;
        uint256 rewardDebt;
        uint256 stakedAt;
        bool isSequencer;
        uint256 lastStakeBlock;
        uint256 lastStakeTimestamp;
    }
    
    function getStakeInfo(address user) external view returns (StakeInfo memory);
    function getVotingPowerWithFlashLoanProtection(address user) external view returns (uint256);
}

/**
 * @title GovernorDualTokenVoting
 * @author Ande Labs
 * @notice Extensión de Governor que combina voting power de token + staking
 * 
 * FÓRMULA DE VOTING POWER:
 * totalVotes = baseVotes + stakingBonus
 * 
 * Donde:
 * - baseVotes = ANDETokenDuality.getPastVotes() 
 * - stakingBonus = votingPower del AndeNativeStaking (ya incluye multiplier)
 * 
 * EJEMPLO:
 * Usuario con 10,000 ANDE delegados + 50,000 ANDE staked (12 meses):
 * - baseVotes: 10,000 ANDE
 * - stakingBonus: 50,000 * 1.5 = 75,000 ANDE (calculado por AndeNativeStaking)
 * - totalVotes: 85,000 ANDE equivalente
 * 
 * CARACTERÍSTICAS:
 * - Compatible con sistema de 3 niveles de staking (Liquidity, Governance, Sequencer)
 * - Protección anti-whale: límite de 500% bonus sobre base votes
 * - Incentiva staking de largo plazo (mayor lock period = mayor voting power)
 * - Actualizable vía governance
 */
abstract contract GovernorDualTokenVoting is GovernorVotesUpgradeable {
    
    IAndeNativeStaking public stakingContract;
    
    uint256 public constant MAX_STAKING_BONUS_BPS = 50000;
    
    event StakingContractUpdated(address indexed oldContract, address indexed newContract);
    event VotingPowerQueried(
        address indexed account, 
        uint256 blockNumber, 
        uint256 baseVotes, 
        uint256 stakingBonus, 
        uint256 totalVotes
    );
    
    error InvalidStakingContract();
    error InvalidGovernanceToken();
    
    function __GovernorDualTokenVoting_init(
        IVotes _governanceToken,
        IAndeNativeStaking _stakingContract
    ) internal onlyInitializing {
        if (address(_governanceToken) == address(0)) revert InvalidGovernanceToken();
        if (address(_stakingContract) == address(0)) revert InvalidStakingContract();
        
        __GovernorVotes_init(_governanceToken);
        stakingContract = _stakingContract;
    }
    
    /**
     * @notice Calcula el voting power total combinando token + staking
     * @dev Override del método base de Governor
     * @param account Dirección del votante
     * @param timepoint Bloque en el que se consulta el voting power
     * @param params Parámetros adicionales (no usados actualmente)
     * @return Voting power total
     */
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory params
    ) internal view virtual override returns (uint256) {
        uint256 baseVotes = super._getVotes(account, timepoint, params);
        
        uint256 stakingBonus = _calculateStakingBonus(account);
        
        if (stakingBonus > (baseVotes * MAX_STAKING_BONUS_BPS) / 10000) {
            stakingBonus = (baseVotes * MAX_STAKING_BONUS_BPS) / 10000;
        }
        
        uint256 totalVotes = baseVotes + stakingBonus;
        
        return totalVotes;
    }
    
    /**
     * @notice Calcula el bonus de voting power por staking
     * @dev Lee del contrato AndeNativeStaking que ya aplica multipliers según lock period
     * @param account Dirección del staker
     * @return Voting power bonus del staking
     */
    function _calculateStakingBonus(address account) internal view returns (uint256) {
        return stakingContract.getVotingPowerWithFlashLoanProtection(account);
    }
    
    /**
     * @notice Permite actualizar el contrato de staking
     * @dev Solo governance puede llamar esto
     * @param newStakingContract Nueva dirección del contrato de staking
     */
    function updateStakingContract(IAndeNativeStaking newStakingContract) 
        external 
        virtual 
        onlyGovernance 
    {
        if (address(newStakingContract) == address(0)) revert InvalidStakingContract();
        
        address oldContract = address(stakingContract);
        stakingContract = newStakingContract;
        
        emit StakingContractUpdated(oldContract, address(newStakingContract));
    }
    
    /**
     * @notice Vista pública para consultar voting power total desglosado
     * @param account Dirección a consultar
     * @param timepoint Bloque en el que se consulta
     * @return baseVotes Votes del token governance
     * @return stakingBonus Bonus por staking (con cap aplicado)
     * @return totalVotes Total voting power
     */
    function getVotesWithStaking(address account, uint256 timepoint) 
        external 
        view 
        returns (
            uint256 baseVotes,
            uint256 stakingBonus,
            uint256 totalVotes
        ) 
    {
        baseVotes = token().getPastVotes(account, timepoint);
        stakingBonus = _calculateStakingBonus(account);
        
        if (stakingBonus > (baseVotes * MAX_STAKING_BONUS_BPS) / 10000) {
            stakingBonus = (baseVotes * MAX_STAKING_BONUS_BPS) / 10000;
        }
        
        totalVotes = baseVotes + stakingBonus;
    }
    
    /**
     * @notice Retorna el voting power actual de una cuenta (sin timepoint)
     * @param account Dirección a consultar
     * @return Voting power total actual
     */
    function getCurrentVotes(address account) 
        external 
        view 
        returns (uint256) 
    {
        uint256 currentTimepoint = clock();
        if (currentTimepoint == 0) return 0;
        
        uint256 baseVotes = token().getPastVotes(account, currentTimepoint - 1);
        uint256 stakingBonus = _calculateStakingBonus(account);
        
        if (stakingBonus > (baseVotes * MAX_STAKING_BONUS_BPS) / 10000) {
            stakingBonus = (baseVotes * MAX_STAKING_BONUS_BPS) / 10000;
        }
        
        return baseVotes + stakingBonus;
    }
    
    /**
     * @notice Retorna información de staking de una cuenta
     * @param account Dirección a consultar
     * @return Información completa del stake
     */
    function getStakingInfo(address account) 
        external 
        view 
        returns (IAndeNativeStaking.StakeInfo memory) 
    {
        return stakingContract.getStakeInfo(account);
    }
}
