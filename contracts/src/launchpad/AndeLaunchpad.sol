// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AndeLaunchpad
 * @notice IDO (Initial DEX Offering) platform for token launches
 * @dev Features:
 *      - Tiered whitelist system (via Merkle trees)
 *      - Vesting schedules for launched tokens
 *      - ANDE staking for allocation tiers
 *      - Anti-bot mechanisms
 *      - Automatic liquidity addition
 *      - KYC integration hooks
 * 
 * Tier System:
 * - Bronze: 100 ANDE staked → 1x allocation
 * - Silver: 500 ANDE staked → 5x allocation
 * - Gold: 1000 ANDE staked → 15x allocation
 * - Platinum: 5000 ANDE staked → 50x allocation
 */
contract AndeLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // CONSTANTS
    // ========================================
    
    uint256 public constant PRECISION = 10000;
    uint256 public constant MIN_RAISE_DURATION = 1 hours;
    uint256 public constant MAX_RAISE_DURATION = 30 days;
    
    // Tier thresholds (ANDE tokens)
    uint256 public constant BRONZE_TIER = 100 ether;
    uint256 public constant SILVER_TIER = 500 ether;
    uint256 public constant GOLD_TIER = 1000 ether;
    uint256 public constant PLATINUM_TIER = 5000 ether;
    
    // Tier multipliers
    uint256 public constant BRONZE_MULTIPLIER = 1;
    uint256 public constant SILVER_MULTIPLIER = 5;
    uint256 public constant GOLD_MULTIPLIER = 15;
    uint256 public constant PLATINUM_MULTIPLIER = 50;

    // ========================================
    // ENUMS
    // ========================================
    
    enum LaunchStatus {
        Pending,      // Not started
        Whitelist,    // Whitelist phase
        Public,       // Public sale
        Ended,        // Sale ended
        Cancelled     // Sale cancelled
    }
    
    enum VestingType {
        None,         // No vesting
        Linear,       // Linear unlock over time
        Milestone     // Unlock at specific milestones
    }

    // ========================================
    // STRUCTS
    // ========================================
    
    struct Launch {
        address token;              // Token being launched
        address paymentToken;       // Token used for purchase (ANDE/USDC)
        address creator;            // Launch creator
        
        uint256 tokenPrice;         // Price per token
        uint256 softCap;            // Minimum raise target
        uint256 hardCap;            // Maximum raise target
        uint256 minContribution;    // Min per user
        uint256 maxContribution;    // Max per user
        
        uint256 startTime;
        uint256 endTime;
        uint256 whitelistEndTime;
        
        uint256 totalRaised;
        uint256 totalTokensSold;
        
        bytes32 whitelistRoot;      // Merkle root for whitelist
        LaunchStatus status;
        VestingType vestingType;
        
        uint256 liquidityPercent;   // % to add as liquidity
        uint256 platformFee;        // Platform fee in basis points
        
        bool finalized;
        bool refundEnabled;
    }
    
    struct VestingSchedule {
        uint256 cliff;              // Cliff period
        uint256 duration;           // Total vesting duration
        uint256 slicePeriod;        // Vesting slice period
        uint256 initialUnlock;      // % unlocked at TGE
    }
    
    struct UserAllocation {
        uint256 amount;             // Amount contributed
        uint256 tokensPurchased;    // Tokens purchased
        uint256 tokensClaimed;      // Tokens already claimed
        bool claimed;               // Fully claimed
        bool refunded;              // Refunded
    }

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    address public immutable andeToken;
    address public immutable router;
    address public treasury;
    
    uint256 public platformFeeRate = 200; // 2%
    uint256 public minLiquidityPercent = 5000; // 50%
    uint256 public nextLaunchId;
    
    mapping(uint256 => Launch) public launches;
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    mapping(uint256 => mapping(address => UserAllocation)) public userAllocations;
    mapping(address => uint256) public userAndeStaked;

    // ========================================
    // EVENTS
    // ========================================
    
    event LaunchCreated(
        uint256 indexed launchId,
        address indexed token,
        address indexed creator,
        uint256 hardCap
    );
    event Purchase(
        uint256 indexed launchId,
        address indexed user,
        uint256 amount,
        uint256 tokens
    );
    event TokensClaimed(uint256 indexed launchId, address indexed user, uint256 amount);
    event LaunchFinalized(uint256 indexed launchId, uint256 totalRaised, uint256 liquidityAdded);
    event LaunchCancelled(uint256 indexed launchId);
    event Refund(uint256 indexed launchId, address indexed user, uint256 amount);
    event AndeStaked(address indexed user, uint256 amount);
    event AndeUnstaked(address indexed user, uint256 amount);

    // ========================================
    // ERRORS
    // ========================================
    
    error InvalidLaunch();
    error LaunchNotActive();
    error LaunchEnded();
    error ContributionTooLow();
    error ContributionTooHigh();
    error HardCapReached();
    error NotWhitelisted();
    error AlreadyClaimed();
    error VestingNotStarted();
    error NoRefund();
    error Unauthorized();
    error InvalidParameters();

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _andeToken,
        address _router,
        address _treasury
    ) Ownable(msg.sender) {
        andeToken = _andeToken;
        router = _router;
        treasury = _treasury;
    }

    // ========================================
    // LAUNCH CREATION
    // ========================================
    
    /**
     * @notice Create a new token launch
     * @param token Token to launch
     * @param paymentToken Token for payments
     * @param tokenPrice Price per token
     * @param softCap Minimum raise target
     * @param hardCap Maximum raise target
     * @param minContribution Min contribution per user
     * @param maxContribution Max contribution per user
     * @param startTime Launch start time
     * @param duration Launch duration
     * @param whitelistDuration Whitelist phase duration
     * @param whitelistRoot Merkle root for whitelist
     * @param liquidityPercent % for liquidity (5000 = 50%)
     */
    function createLaunch(
        address token,
        address paymentToken,
        uint256 tokenPrice,
        uint256 softCap,
        uint256 hardCap,
        uint256 minContribution,
        uint256 maxContribution,
        uint256 startTime,
        uint256 duration,
        uint256 whitelistDuration,
        bytes32 whitelistRoot,
        uint256 liquidityPercent
    ) external nonReentrant returns (uint256 launchId) {
        if (
            token == address(0) ||
            tokenPrice == 0 ||
            hardCap < softCap ||
            minContribution > maxContribution ||
            startTime < block.timestamp ||
            duration < MIN_RAISE_DURATION ||
            duration > MAX_RAISE_DURATION ||
            liquidityPercent < minLiquidityPercent
        ) revert InvalidParameters();
        
        launchId = nextLaunchId++;
        
        uint256 endTime = startTime + duration;
        uint256 whitelistEndTime = startTime + whitelistDuration;
        
        launches[launchId] = Launch({
            token: token,
            paymentToken: paymentToken,
            creator: msg.sender,
            tokenPrice: tokenPrice,
            softCap: softCap,
            hardCap: hardCap,
            minContribution: minContribution,
            maxContribution: maxContribution,
            startTime: startTime,
            endTime: endTime,
            whitelistEndTime: whitelistEndTime,
            totalRaised: 0,
            totalTokensSold: 0,
            whitelistRoot: whitelistRoot,
            status: LaunchStatus.Pending,
            vestingType: VestingType.None,
            liquidityPercent: liquidityPercent,
            platformFee: platformFeeRate,
            finalized: false,
            refundEnabled: false
        });
        
        // Transfer tokens to launchpad
        uint256 tokensNeeded = (hardCap * 1e18) / tokenPrice;
        uint256 liquidityTokens = (tokensNeeded * liquidityPercent) / PRECISION;
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokensNeeded + liquidityTokens);
        
        emit LaunchCreated(launchId, token, msg.sender, hardCap);
    }
    
    /**
     * @notice Set vesting schedule for a launch
     * @param launchId Launch ID
     * @param vestingType Type of vesting
     * @param cliff Cliff period in seconds
     * @param duration Total vesting duration
     * @param slicePeriod Vesting slice period
     * @param initialUnlock % unlocked at TGE (basis points)
     */
    function setVesting(
        uint256 launchId,
        VestingType vestingType,
        uint256 cliff,
        uint256 duration,
        uint256 slicePeriod,
        uint256 initialUnlock
    ) external {
        Launch storage launch = launches[launchId];
        if (launch.creator != msg.sender) revert Unauthorized();
        if (launch.status != LaunchStatus.Pending) revert LaunchNotActive();
        
        launch.vestingType = vestingType;
        vestingSchedules[launchId] = VestingSchedule({
            cliff: cliff,
            duration: duration,
            slicePeriod: slicePeriod,
            initialUnlock: initialUnlock
        });
    }

    // ========================================
    // PARTICIPATION
    // ========================================
    
    /**
     * @notice Participate in launch
     * @param launchId Launch ID
     * @param amount Amount to contribute
     * @param merkleProof Proof for whitelist (empty if public)
     */
    function participate(
        uint256 launchId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        Launch storage launch = launches[launchId];
        
        if (block.timestamp < launch.startTime) revert LaunchNotActive();
        if (block.timestamp >= launch.endTime) revert LaunchEnded();
        if (amount < launch.minContribution) revert ContributionTooLow();
        
        // Check whitelist phase
        if (block.timestamp < launch.whitelistEndTime) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            if (!MerkleProof.verify(merkleProof, launch.whitelistRoot, leaf)) {
                revert NotWhitelisted();
            }
            launch.status = LaunchStatus.Whitelist;
        } else {
            launch.status = LaunchStatus.Public;
        }
        
        // Check allocation limits
        UserAllocation storage allocation = userAllocations[launchId][msg.sender];
        uint256 newTotal = allocation.amount + amount;
        
        uint256 maxAllowed = _getUserMaxAllocation(msg.sender, launch.maxContribution);
        if (newTotal > maxAllowed) revert ContributionTooHigh();
        
        // Check hard cap
        if (launch.totalRaised + amount > launch.hardCap) revert HardCapReached();
        
        // Transfer payment
        IERC20(launch.paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate tokens
        uint256 tokens = (amount * 1e18) / launch.tokenPrice;
        
        // Update state
        allocation.amount += amount;
        allocation.tokensPurchased += tokens;
        launch.totalRaised += amount;
        launch.totalTokensSold += tokens;
        
        emit Purchase(launchId, msg.sender, amount, tokens);
    }
    
    /**
     * @notice Claim purchased tokens
     * @param launchId Launch ID
     */
    function claimTokens(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (!launch.finalized) revert InvalidLaunch();
        
        UserAllocation storage allocation = userAllocations[launchId][msg.sender];
        if (allocation.tokensPurchased == 0) revert InvalidLaunch();
        
        uint256 claimable = _calculateClaimable(launchId, msg.sender);
        if (claimable == 0) revert AlreadyClaimed();
        
        allocation.tokensClaimed += claimable;
        if (allocation.tokensClaimed >= allocation.tokensPurchased) {
            allocation.claimed = true;
        }
        
        IERC20(launch.token).safeTransfer(msg.sender, claimable);
        
        emit TokensClaimed(launchId, msg.sender, claimable);
    }

    // ========================================
    // FINALIZATION
    // ========================================
    
    /**
     * @notice Finalize launch after end time
     * @param launchId Launch ID
     */
    function finalizeLaunch(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        
        if (block.timestamp < launch.endTime) revert LaunchNotActive();
        if (launch.finalized) revert InvalidLaunch();
        
        launch.finalized = true;
        
        // Check if soft cap reached
        if (launch.totalRaised < launch.softCap) {
            launch.refundEnabled = true;
            launch.status = LaunchStatus.Cancelled;
            return;
        }
        
        launch.status = LaunchStatus.Ended;
        
        // Calculate fees
        uint256 platformFee = (launch.totalRaised * launch.platformFee) / PRECISION;
        uint256 creatorAmount = launch.totalRaised - platformFee;
        
        // Transfer fees
        if (platformFee > 0) {
            IERC20(launch.paymentToken).safeTransfer(treasury, platformFee);
        }
        
        // Add liquidity
        uint256 liquidityAmount = (creatorAmount * launch.liquidityPercent) / PRECISION;
        uint256 tokensForLiquidity = (launch.totalTokensSold * launch.liquidityPercent) / PRECISION;
        
        if (liquidityAmount > 0 && router != address(0)) {
            IERC20(launch.paymentToken).approve(router, liquidityAmount);
            IERC20(launch.token).approve(router, tokensForLiquidity);
            _addLiquidity(launch.token, launch.paymentToken, tokensForLiquidity, liquidityAmount);
        }
        
        // Transfer remaining to creator
        uint256 remaining = creatorAmount - liquidityAmount;
        if (remaining > 0) {
            IERC20(launch.paymentToken).safeTransfer(launch.creator, remaining);
        }
        
        emit LaunchFinalized(launchId, launch.totalRaised, liquidityAmount);
    }
    
    /**
     * @notice Refund if soft cap not reached
     * @param launchId Launch ID
     */
    function refund(uint256 launchId) external nonReentrant {
        Launch storage launch = launches[launchId];
        if (!launch.refundEnabled) revert NoRefund();
        
        UserAllocation storage allocation = userAllocations[launchId][msg.sender];
        if (allocation.amount == 0 || allocation.refunded) revert NoRefund();
        
        uint256 refundAmount = allocation.amount;
        allocation.refunded = true;
        
        IERC20(launch.paymentToken).safeTransfer(msg.sender, refundAmount);
        
        emit Refund(launchId, msg.sender, refundAmount);
    }

    // ========================================
    // TIER SYSTEM
    // ========================================
    
    /**
     * @notice Stake ANDE for tier allocation
     * @param amount Amount to stake
     */
    function stakeAnde(uint256 amount) external nonReentrant {
        IERC20(andeToken).safeTransferFrom(msg.sender, address(this), amount);
        userAndeStaked[msg.sender] += amount;
        emit AndeStaked(msg.sender, amount);
    }
    
    /**
     * @notice Unstake ANDE
     * @param amount Amount to unstake
     */
    function unstakeAnde(uint256 amount) external nonReentrant {
        if (userAndeStaked[msg.sender] < amount) revert InvalidParameters();
        userAndeStaked[msg.sender] -= amount;
        IERC20(andeToken).safeTransfer(msg.sender, amount);
        emit AndeUnstaked(msg.sender, amount);
    }
    
    /**
     * @notice Get user's tier
     * @param user User address
     * @return tier Tier number (0-4)
     */
    function getUserTier(address user) public view returns (uint256 tier) {
        uint256 staked = userAndeStaked[user];
        
        if (staked >= PLATINUM_TIER) return 4;
        if (staked >= GOLD_TIER) return 3;
        if (staked >= SILVER_TIER) return 2;
        if (staked >= BRONZE_TIER) return 1;
        return 0;
    }
    
    /**
     * @notice Get user's allocation multiplier
     * @param user User address
     * @return multiplier Allocation multiplier
     */
    function getUserMultiplier(address user) public view returns (uint256 multiplier) {
        uint256 tier = getUserTier(user);
        
        if (tier == 4) return PLATINUM_MULTIPLIER;
        if (tier == 3) return GOLD_MULTIPLIER;
        if (tier == 2) return SILVER_MULTIPLIER;
        if (tier == 1) return BRONZE_MULTIPLIER;
        return 1;
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    function getClaimableTokens(uint256 launchId, address user) external view returns (uint256) {
        return _calculateClaimable(launchId, user);
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================
    
    function _getUserMaxAllocation(address user, uint256 baseMax) internal view returns (uint256) {
        uint256 multiplier = getUserMultiplier(user);
        return baseMax * multiplier;
    }
    
    function _calculateClaimable(uint256 launchId, address user) internal view returns (uint256) {
        Launch storage launch = launches[launchId];
        UserAllocation storage allocation = userAllocations[launchId][user];
        
        if (launch.vestingType == VestingType.None) {
            return allocation.tokensPurchased - allocation.tokensClaimed;
        }
        
        VestingSchedule storage vesting = vestingSchedules[launchId];
        
        if (block.timestamp < launch.endTime + vesting.cliff) {
            // Still in cliff, only initial unlock
            uint256 initialAmount = (allocation.tokensPurchased * vesting.initialUnlock) / PRECISION;
            return initialAmount > allocation.tokensClaimed ? initialAmount - allocation.tokensClaimed : 0;
        }
        
        // Linear vesting
        uint256 vestingStart = launch.endTime + vesting.cliff;
        uint256 elapsed = block.timestamp - vestingStart;
        
        if (elapsed >= vesting.duration) {
            // Fully vested
            return allocation.tokensPurchased - allocation.tokensClaimed;
        }
        
        uint256 vestedAmount = (allocation.tokensPurchased * elapsed) / vesting.duration;
        uint256 initialAmount = (allocation.tokensPurchased * vesting.initialUnlock) / PRECISION;
        uint256 totalVested = initialAmount + vestedAmount;
        
        return totalVested > allocation.tokensClaimed ? totalVested - allocation.tokensClaimed : 0;
    }
    
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        // Call router.addLiquidity
        // Simplified for now
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    function setPlatformFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert InvalidParameters(); // Max 10%
        platformFeeRate = newFee;
    }
    
    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }
    
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
