// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../gauges/VotingEscrow.sol";

/**
 * @title MEVDistributor
 * @notice Distributes MEV revenue to veANDE stakers, protocol, and treasury
 * @dev Core contract for MEV redistribution in AndeChain
 * @author Ande Labs
 */
contract MEVDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    /// @notice VotingEscrow contract for veANDE
    VotingEscrow public immutable votingEscrow;
    
    /// @notice ANDE token contract
    IERC20 public immutable andeToken;
    
    /// @notice Protocol treasury address
    address public treasury;
    
    /// @notice Protocol fee collector address
    address public protocolFeeCollector;
    
    /// @notice Sequencer address authorized to deposit MEV
    address public sequencer;
    
    /// @notice Current epoch number
    uint256 public currentEpoch;
    
    /// @notice Epoch duration in seconds (1 week)
    uint256 public constant EPOCH_DURATION = 7 days;
    
    /// @notice Start timestamp of current epoch
    uint256 public epochStartTime;
    
    // Distribution percentages (basis points, 10000 = 100%)
    uint256 public constant STAKERS_SHARE = 8000;      // 80%
    uint256 public constant PROTOCOL_FEE = 1500;       // 15%
    uint256 public constant TREASURY_SHARE = 500;      // 5%
    
    /// @notice Whether MEV capture is paused
    bool public mevCapturePaused;
    
    // ========================================
    // STRUCTS
    // ========================================
    
    struct EpochData {
        uint256 totalMEVCaptured;      // Total MEV in this epoch
        uint256 totalVotingPower;       // Total veANDE power at epoch
        uint256 stakersReward;          // Amount for stakers
        uint256 protocolFee;            // Amount for protocol
        uint256 treasuryAmount;         // Amount for treasury
        bool settled;                   // Whether epoch is settled
        uint256 timestamp;              // Epoch end timestamp
    }
    
    struct UserClaim {
        uint256 lastClaimedEpoch;      // Last epoch user claimed
        uint256 totalClaimed;           // Total MEV claimed by user
    }
    
    // ========================================
    // MAPPINGS
    // ========================================
    
    /// @notice Epoch number => EpochData
    mapping(uint256 => EpochData) public epochs;
    
    /// @notice User address => UserClaim
    mapping(address => UserClaim) public userClaims;
    
    /// @notice User => Epoch => Claimed amount
    mapping(address => mapping(uint256 => uint256)) public claimedByEpoch;
    
    // ========================================
    // EVENTS
    // ========================================
    
    event MEVDeposited(
        uint256 indexed epoch,
        uint256 amount,
        address indexed depositor
    );
    
    event EpochSettled(
        uint256 indexed epoch,
        uint256 totalMEV,
        uint256 stakersReward,
        uint256 protocolFee,
        uint256 treasuryAmount
    );
    
    event RewardsClaimed(
        address indexed user,
        uint256 indexed epoch,
        uint256 amount
    );
    
    event SequencerUpdated(address indexed oldSequencer, address indexed newSequencer);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event ProtocolFeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);
    event MEVCaptureStatusChanged(bool paused);
    
    // ========================================
    // ERRORS
    // ========================================
    
    error OnlySequencer();
    error AmountMustBePositive();
    error EpochNotFinished();
    error NothingToClaim();
    error CannotClaimCurrentEpoch();
    error AlreadyRegistered();
    error InvalidAddress();
    error MEVCaptureIsPaused();
    
    // ========================================
    // MODIFIERS
    // ========================================
    
    modifier onlySequencer() {
        if (msg.sender != sequencer) revert OnlySequencer();
        _;
    }
    
    modifier whenMEVCaptureActive() {
        if (mevCapturePaused) revert MEVCaptureIsPaused();
        _;
    }
    
    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _votingEscrow,
        address _andeToken,
        address _treasury,
        address _protocolFeeCollector,
        address _sequencer
    ) Ownable(msg.sender) {
        if (_votingEscrow == address(0)) revert InvalidAddress();
        if (_andeToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_protocolFeeCollector == address(0)) revert InvalidAddress();
        if (_sequencer == address(0)) revert InvalidAddress();
        
        votingEscrow = VotingEscrow(_votingEscrow);
        andeToken = IERC20(_andeToken);
        treasury = _treasury;
        protocolFeeCollector = _protocolFeeCollector;
        sequencer = _sequencer;
        
        epochStartTime = block.timestamp;
        currentEpoch = 1;
    }
    
    // ========================================
    // CORE FUNCTIONS
    // ========================================
    
    /**
     * @notice Deposit MEV revenue from sequencer
     * @param amount Amount of ANDE tokens from MEV
     * @dev Called by sequencer after converting ETH MEV to ANDE
     */
    function depositMEV(uint256 amount) external onlySequencer whenMEVCaptureActive nonReentrant {
        if (amount == 0) revert AmountMustBePositive();
        
        // Transfer ANDE from sequencer
        andeToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Check if epoch needs to be advanced
        if (block.timestamp >= epochStartTime + EPOCH_DURATION) {
            _settleEpoch();
        }
        
        // Add to current epoch
        epochs[currentEpoch].totalMEVCaptured += amount;
        
        emit MEVDeposited(currentEpoch, amount, msg.sender);
    }
    
    /**
     * @notice Settle current epoch and start new one
     * @dev Can be called by anyone after epoch duration
     */
    function settleEpoch() external nonReentrant {
        if (block.timestamp < epochStartTime + EPOCH_DURATION) {
            revert EpochNotFinished();
        }
        _settleEpoch();
    }
    
    /**
     * @notice Internal epoch settlement
     */
    function _settleEpoch() internal {
        EpochData storage epoch = epochs[currentEpoch];
        
        if (epoch.settled) return;
        
        uint256 totalMEV = epoch.totalMEVCaptured;
        
        if (totalMEV > 0) {
            // Calculate splits
            epoch.stakersReward = (totalMEV * STAKERS_SHARE) / 10000;
            epoch.protocolFee = (totalMEV * PROTOCOL_FEE) / 10000;
            epoch.treasuryAmount = (totalMEV * TREASURY_SHARE) / 10000;
            
            // Get total voting power at epoch end
            try votingEscrow.totalSupplyAt(block.timestamp) returns (uint256 totalSupply) {
                epoch.totalVotingPower = totalSupply;
            } catch {
                epoch.totalVotingPower = 0;
            }
            
            // Transfer protocol fee and treasury
            if (epoch.protocolFee > 0) {
                andeToken.safeTransfer(protocolFeeCollector, epoch.protocolFee);
            }
            if (epoch.treasuryAmount > 0) {
                andeToken.safeTransfer(treasury, epoch.treasuryAmount);
            }
        }
        
        epoch.settled = true;
        epoch.timestamp = block.timestamp;
        
        emit EpochSettled(
            currentEpoch,
            totalMEV,
            epoch.stakersReward,
            epoch.protocolFee,
            epoch.treasuryAmount
        );
        
        // Start new epoch
        currentEpoch++;
        epochStartTime = block.timestamp;
    }
    
    /**
     * @notice Claim MEV rewards for multiple epochs
     * @param upToEpoch Claim up to this epoch (inclusive)
     */
    function claimRewards(uint256 upToEpoch) external nonReentrant {
        if (upToEpoch >= currentEpoch) revert CannotClaimCurrentEpoch();
        
        UserClaim storage userClaim = userClaims[msg.sender];
        uint256 startEpoch = userClaim.lastClaimedEpoch + 1;
        
        if (startEpoch > upToEpoch) revert NothingToClaim();
        
        uint256 totalReward = 0;
        
        // Iterate through epochs and calculate rewards
        for (uint256 i = startEpoch; i <= upToEpoch; i++) {
            EpochData storage epoch = epochs[i];
            
            if (!epoch.settled) continue;
            if (epoch.stakersReward == 0) continue;
            if (epoch.totalVotingPower == 0) continue;
            
            // Get user's voting power at epoch end
            uint256 userVotingPower;
            try votingEscrow.balanceOfAt(msg.sender, epoch.timestamp) returns (uint256 balance) {
                userVotingPower = balance;
            } catch {
                userVotingPower = 0;
            }
            
            if (userVotingPower == 0) continue;
            
            // Calculate user's share
            uint256 userShare = (epoch.stakersReward * userVotingPower) / 
                                 epoch.totalVotingPower;
            
            totalReward += userShare;
            claimedByEpoch[msg.sender][i] = userShare;
            
            emit RewardsClaimed(msg.sender, i, userShare);
        }
        
        if (totalReward == 0) revert NothingToClaim();
        
        // Update claim data
        userClaim.lastClaimedEpoch = upToEpoch;
        userClaim.totalClaimed += totalReward;
        
        // Transfer rewards
        andeToken.safeTransfer(msg.sender, totalReward);
    }
    
    /**
     * @notice View pending rewards for user
     * @param user User address
     * @param upToEpoch Check up to this epoch
     * @return Total pending rewards
     */
    function pendingRewards(
        address user,
        uint256 upToEpoch
    ) external view returns (uint256) {
        UserClaim storage userClaim = userClaims[user];
        uint256 startEpoch = userClaim.lastClaimedEpoch + 1;
        
        if (startEpoch > upToEpoch || upToEpoch >= currentEpoch) {
            return 0;
        }
        
        uint256 totalReward = 0;
        
        for (uint256 i = startEpoch; i <= upToEpoch; i++) {
            EpochData storage epoch = epochs[i];
            
            if (!epoch.settled || epoch.stakersReward == 0 || epoch.totalVotingPower == 0) {
                continue;
            }
            
            uint256 userVotingPower;
            try votingEscrow.balanceOfAt(user, epoch.timestamp) returns (uint256 balance) {
                userVotingPower = balance;
            } catch {
                userVotingPower = 0;
            }
            
            if (userVotingPower == 0) continue;
            
            uint256 userShare = (epoch.stakersReward * userVotingPower) / 
                                 epoch.totalVotingPower;
            
            totalReward += userShare;
        }
        
        return totalReward;
    }
    
    /**
     * @notice Get current epoch info
     * @return epoch Current epoch number
     * @return startTime Epoch start time
     * @return endTime Epoch end time
     * @return timeRemaining Time until epoch ends
     */
    function getCurrentEpochInfo() external view returns (
        uint256 epoch,
        uint256 startTime,
        uint256 endTime,
        uint256 timeRemaining
    ) {
        epoch = currentEpoch;
        startTime = epochStartTime;
        endTime = epochStartTime + EPOCH_DURATION;
        timeRemaining = endTime > block.timestamp ? endTime - block.timestamp : 0;
    }
    
    /**
     * @notice Get epoch data
     * @param epochId Epoch number
     * @return totalMEV Total MEV captured
     * @return stakersReward Amount for stakers
     * @return protocolFee Amount for protocol
     * @return treasuryAmount Amount for treasury
     * @return settled Whether epoch is settled
     * @return timestamp Epoch end timestamp
     */
    function getEpochData(uint256 epochId) external view returns (
        uint256 totalMEV,
        uint256 stakersReward,
        uint256 protocolFee,
        uint256 treasuryAmount,
        bool settled,
        uint256 timestamp
    ) {
        EpochData storage epoch = epochs[epochId];
        return (
            epoch.totalMEVCaptured,
            epoch.stakersReward,
            epoch.protocolFee,
            epoch.treasuryAmount,
            epoch.settled,
            epoch.timestamp
        );
    }
    
    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Update sequencer address
     * @param newSequencer New sequencer address
     */
    function updateSequencer(address newSequencer) external onlyOwner {
        if (newSequencer == address(0)) revert InvalidAddress();
        emit SequencerUpdated(sequencer, newSequencer);
        sequencer = newSequencer;
    }
    
    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }
    
    /**
     * @notice Update protocol fee collector address
     * @param newCollector New collector address
     */
    function updateProtocolFeeCollector(address newCollector) external onlyOwner {
        if (newCollector == address(0)) revert InvalidAddress();
        emit ProtocolFeeCollectorUpdated(protocolFeeCollector, newCollector);
        protocolFeeCollector = newCollector;
    }
    
    /**
     * @notice Pause or unpause MEV capture
     * @param paused Whether to pause MEV capture
     */
    function setMEVCapturePaused(bool paused) external onlyOwner {
        mevCapturePaused = paused;
        emit MEVCaptureStatusChanged(paused);
    }
    
    /**
     * @notice Emergency withdraw tokens (owner only)
     * @param token Token address
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();
        
        IERC20(token).safeTransfer(to, amount);
    }
}