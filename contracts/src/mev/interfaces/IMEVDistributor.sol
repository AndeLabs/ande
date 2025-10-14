// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IMEVDistributor
 * @notice Interface for MEV Distributor contract
 */
interface IMEVDistributor {
    // ========================================
    // STRUCTS
    // ========================================
    
    struct EpochData {
        uint256 totalMEVCaptured;
        uint256 totalVotingPower;
        uint256 stakersReward;
        uint256 protocolFee;
        uint256 treasuryAmount;
        bool settled;
        uint256 timestamp;
    }
    
    struct UserClaim {
        uint256 lastClaimedEpoch;
        uint256 totalClaimed;
    }
    
    // ========================================
    // FUNCTIONS
    // ========================================
    
    function depositMEV(uint256 amount) external;
    function settleEpoch() external;
    function claimRewards(uint256 upToEpoch) external;
    function pendingRewards(address user, uint256 upToEpoch) external view returns (uint256);
    function getCurrentEpochInfo() external view returns (uint256 epoch, uint256 startTime, uint256 endTime, uint256 timeRemaining);
    function getEpochData(uint256 epochId) external view returns (uint256 totalMEV, uint256 stakersReward, uint256 protocolFee, uint256 treasuryAmount, bool settled, uint256 timestamp);
    
    // ========================================
    // VARIABLES
    // ========================================
    
    function votingEscrow() external view returns (address);
    function andeToken() external view returns (IERC20);
    function treasury() external view returns (address);
    function protocolFeeCollector() external view returns (address);
    function sequencer() external view returns (address);
    function currentEpoch() external view returns (uint256);
    function epochStartTime() external view returns (uint256);
    function mevCapturePaused() external view returns (bool);
    
    // ========================================
    // CONSTANTS
    // ========================================
    
    function EPOCH_DURATION() external view returns (uint256);
    function STAKERS_SHARE() external view returns (uint256);
    function PROTOCOL_FEE() external view returns (uint256);
    function TREASURY_SHARE() external view returns (uint256);
}