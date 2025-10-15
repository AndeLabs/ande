// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MEVAuctionManager
 * @notice Manages MEV bundle auctions (Flashbots-style)
 * @dev Searchers submit bundles off-chain, sequencer selects winner
 * @author Ande Labs
 */
contract MEVAuctionManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    /// @notice Sequencer address authorized to execute bundles
    address public sequencer;
    
    /// @notice ANDE token contract for bid payments
    IERC20 public immutable andeToken;
    
    /// @notice Minimum bid amount in ANDE tokens
    uint256 public minimumBid;
    
    /// @notice Registration deposit amount (refundable)
    uint256 public registrationDeposit;
    
    /// @notice Whether registration is open
    bool public registrationOpen;
    
    /// @notice Mapping of registered searchers
    mapping(address => bool) public registeredSearchers;
    
    /// @notice Mapping of registration deposits
    mapping(address => uint256) public registrationDeposits;
    
    /// @notice Bundle commitment data
    mapping(bytes32 => Bundle) public bundles;
    
    /// @notice Block number => bundle hashes submitted for that block
    mapping(uint256 => bytes32[]) public blockBundles;
    
    /// @notice Searcher => total bundles submitted
    mapping(address => uint256) public searcherBundleCount;
    
    /// @notice Searcher => total MEV captured
    mapping(address => uint256) public searcherMEVCaptured;
    
    // ========================================
    // STRUCTS
    // ========================================
    
    struct Bundle {
        bytes32 bundleHash;           // Hash of the bundle
        address searcher;              // Searcher who submitted
        uint256 bidAmount;            // ANDE tokens bid for inclusion
        uint256 blockNumber;          // Target block number
        bool executed;                // Whether bundle was executed
        uint256 timestamp;            // Submission timestamp
        uint256 mevCaptured;          // Actual MEV captured (set by sequencer)
    }
    
    struct SearcherStats {
        uint256 totalBundles;
        uint256 executedBundles;
        uint256 totalMEVCaptured;
        uint256 totalBidsPaid;
        bool registered;
    }
    
    // ========================================
    // EVENTS
    // ========================================
    
    event SearcherRegistered(address indexed searcher, uint256 deposit);
    event SearcherUnregistered(address indexed searcher, uint256 depositRefunded);
    event BundleSubmitted(
        bytes32 indexed bundleHash,
        address indexed searcher,
        uint256 bidAmount,
        uint256 targetBlock
    );
    event BundleExecuted(
        bytes32 indexed bundleHash,
        address indexed searcher,
        uint256 mevCaptured,
        uint256 bidPaid
    );
    event BundleRejected(bytes32 indexed bundleHash, string reason);
    event MinimumBidUpdated(uint256 oldMinimum, uint256 newMinimum);
    event RegistrationDepositUpdated(uint256 oldDeposit, uint256 newDeposit);
    event RegistrationStatusChanged(bool open);
    event SequencerUpdated(address indexed oldSequencer, address indexed newSequencer);
    
    // ========================================
    // ERRORS
    // ========================================
    
    error OnlySequencer();
    error AlreadyRegistered();
    error NotRegistered();
    error RegistrationClosed();
    error InvalidAmount();
    error BundleNotFound();
    error BundleAlreadyExists();
    error BundleAlreadyExecuted();
    error InvalidBlockNumber();
    error InsufficientDeposit();
    error NoDepositToRefund();
    
    // ========================================
    // MODIFIERS
    // ========================================
    
    modifier onlySequencer() {
        if (msg.sender != sequencer) revert OnlySequencer();
        _;
    }
    
    modifier onlyRegisteredSearcher() {
        if (!registeredSearchers[msg.sender]) revert NotRegistered();
        _;
    }
    
    modifier whenRegistrationOpen() {
        if (!registrationOpen) revert RegistrationClosed();
        _;
    }
    
    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    constructor(
        address _andeToken,
        address _sequencer,
        uint256 _minimumBid,
        uint256 _registrationDeposit
    ) Ownable(msg.sender) {
        if (_andeToken == address(0)) revert InvalidAmount();
        if (_sequencer == address(0)) revert InvalidAmount();
        
        andeToken = IERC20(_andeToken);
        sequencer = _sequencer;
        minimumBid = _minimumBid;
        registrationDeposit = _registrationDeposit;
        registrationOpen = true;
    }
    
    // ========================================
    // SEARCHER MANAGEMENT
    // ========================================
    
    /**
     * @notice Register as MEV searcher
     * @dev Requires deposit that is refundable upon unregistration
     */
    function registerSearcher() external whenRegistrationOpen nonReentrant {
        if (registeredSearchers[msg.sender]) revert AlreadyRegistered();
        
        // Transfer registration deposit
        andeToken.safeTransferFrom(msg.sender, address(this), registrationDeposit);
        
        registeredSearchers[msg.sender] = true;
        registrationDeposits[msg.sender] = registrationDeposit;
        
        emit SearcherRegistered(msg.sender, registrationDeposit);
    }
    
    /**
     * @notice Unregister as searcher and refund deposit
     */
    function unregisterSearcher() external nonReentrant {
        if (!registeredSearchers[msg.sender]) revert NotRegistered();
        
        uint256 deposit = registrationDeposits[msg.sender];
        if (deposit == 0) revert NoDepositToRefund();
        
        // Refund deposit
        andeToken.safeTransfer(msg.sender, deposit);
        
        // Clean up
        registeredSearchers[msg.sender] = false;
        registrationDeposits[msg.sender] = 0;
        
        emit SearcherUnregistered(msg.sender, deposit);
    }
    
    /**
     * @notice Force unregister a searcher (owner only)
     * @param searcher Searcher address to unregister
     */
    function forceUnregisterSearcher(address searcher) external onlyOwner {
        if (!registeredSearchers[searcher]) revert NotRegistered();
        
        uint256 deposit = registrationDeposits[searcher];
        if (deposit > 0) {
            andeToken.safeTransfer(searcher, deposit);
        }
        
        registeredSearchers[searcher] = false;
        registrationDeposits[searcher] = 0;
        
        emit SearcherUnregistered(searcher, deposit);
    }
    
    // ========================================
    // BUNDLE MANAGEMENT
    // ========================================
    
    /**
     * @notice Submit bundle commitment (off-chain bundle, on-chain commitment)
     * @param bundleHash Hash of the bundle (keccak256 of bundle data)
     * @param bidAmount ANDE tokens bid for inclusion
     * @param targetBlock Target block number for inclusion
     */
    function submitBundle(
        bytes32 bundleHash,
        uint256 bidAmount,
        uint256 targetBlock
    ) external onlyRegisteredSearcher nonReentrant {
        if (bidAmount < minimumBid) revert InvalidAmount();
        if (targetBlock <= block.number) revert InvalidBlockNumber();
        if (bundles[bundleHash].searcher != address(0)) revert BundleAlreadyExists();
        
        // Transfer bid amount
        andeToken.safeTransferFrom(msg.sender, address(this), bidAmount);
        
        // Store bundle
        bundles[bundleHash] = Bundle({
            bundleHash: bundleHash,
            searcher: msg.sender,
            bidAmount: bidAmount,
            blockNumber: targetBlock,
            executed: false,
            timestamp: block.timestamp,
            mevCaptured: 0
        });
        
        // Track by block
        blockBundles[targetBlock].push(bundleHash);
        
        // Update searcher stats
        searcherBundleCount[msg.sender]++;
        
        emit BundleSubmitted(bundleHash, msg.sender, bidAmount, targetBlock);
    }
    
    /**
     * @notice Mark bundle as executed (called by sequencer)
     * @param bundleHash Hash of executed bundle
     * @param mevCaptured Actual MEV captured
     * @param bidPaid Actual bid amount to charge (may be less than bid)
     */
    function markBundleExecuted(
        bytes32 bundleHash,
        uint256 mevCaptured,
        uint256 bidPaid
    ) external onlySequencer nonReentrant {
        Bundle storage bundle = bundles[bundleHash];
        if (bundle.searcher == address(0)) revert BundleNotFound();
        if (bundle.executed) revert BundleAlreadyExecuted();
        
        bundle.executed = true;
        bundle.mevCaptured = mevCaptured;
        
        // Update searcher stats
        searcherMEVCaptured[bundle.searcher] += mevCaptured;
        
        // Refund excess bid (if bidPaid < bidAmount)
        uint256 refundAmount = 0;
        if (bidPaid < bundle.bidAmount) {
            refundAmount = bundle.bidAmount - bidPaid;
            andeToken.safeTransfer(bundle.searcher, refundAmount);
        }
        
        // Transfer bid to protocol (or MEV distributor)
        if (bidPaid > 0) {
            andeToken.safeTransfer(owner(), bidPaid); // Owner can forward to MEV distributor
        }
        
        emit BundleExecuted(bundleHash, bundle.searcher, mevCaptured, bidPaid);
    }
    
    /**
     * @notice Mark bundle as rejected (called by sequencer)
     * @param bundleHash Hash of rejected bundle
     * @param reason Reason for rejection
     */
    function markBundleRejected(
        bytes32 bundleHash,
        string calldata reason
    ) external onlySequencer nonReentrant {
        Bundle storage bundle = bundles[bundleHash];
        if (bundle.searcher == address(0)) revert BundleNotFound();
        if (bundle.executed) revert BundleAlreadyExecuted();
        
        bundle.executed = true; // Mark as processed
        bundle.mevCaptured = 0;
        
        // Refund full bid
        andeToken.safeTransfer(bundle.searcher, bundle.bidAmount);
        
        emit BundleRejected(bundleHash, reason);
    }
    
    /**
     * @notice Get bundles for a specific block
     * @param blockNumber Block number
     * @return bundleHashes Array of bundle hashes for that block
     */
    function getBlockBundles(uint256 blockNumber) external view returns (bytes32[] memory bundleHashes) {
        return blockBundles[blockNumber];
    }
    
    /**
     * @notice Get bundle details
     * @param bundleHash Bundle hash
     * @return bundle Bundle data
     */
    function getBundle(bytes32 bundleHash) external view returns (Bundle memory bundle) {
        return bundles[bundleHash];
    }
    
    /**
     * @notice Get searcher statistics
     * @param searcher Searcher address
     * @return stats Searcher statistics
     */
    function getSearcherStats(address searcher) external view returns (SearcherStats memory stats) {
        stats.totalBundles = searcherBundleCount[searcher];
        stats.totalMEVCaptured = searcherMEVCaptured[searcher];
        stats.registered = registeredSearchers[searcher];
        
        // Calculate executed bundles and total bids paid
        uint256 executedCount = 0;
        uint256 totalBids = 0;
        
        // This is a simplified version - in production, you'd want more efficient tracking
        // Check historical and near-future blocks (bundles can be submitted for future blocks)
        uint256 startBlock = block.number > 1000 ? block.number - 1000 : 1;
        uint256 endBlock = block.number + 100; // Check upcoming blocks too
        
        for (uint256 i = startBlock; i <= endBlock; i++) {
            bytes32[] memory hashes = blockBundles[i];
            for (uint256 j = 0; j < hashes.length; j++) {
                Bundle memory bundle = bundles[hashes[j]];
                if (bundle.searcher == searcher) {
                    if (bundle.executed && bundle.mevCaptured > 0) {
                        executedCount++;
                    }
                    totalBids += bundle.bidAmount;
                }
            }
        }
        
        stats.executedBundles = executedCount;
        stats.totalBidsPaid = totalBids;
    }
    
    /**
     * @notice Get current auction statistics
     * @return totalBundles Total bundles submitted
     * @return totalExecuted Total bundles executed
     * @return totalMEVCaptured Total MEV captured
     * @return registeredSearchersCount Number of registered searchers
     */
    function getAuctionStats() external view returns (
        uint256 totalBundles,
        uint256 totalExecuted,
        uint256 totalMEVCaptured,
        uint256 registeredSearchersCount
    ) {
        // Count registered searchers
        // Note: In production, you'd maintain a counter for efficiency
        uint256 count = 0;
        // This is simplified - in production, track this with events or a counter
        
        return (
            0, // Would need to track this properly
            0, // Would need to track this properly
            0, // Would need to track this properly
            count
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
        if (newSequencer == address(0)) revert InvalidAmount();
        emit SequencerUpdated(sequencer, newSequencer);
        sequencer = newSequencer;
    }
    
    /**
     * @notice Update minimum bid amount
     * @param newMinimumBid New minimum bid
     */
    function updateMinimumBid(uint256 newMinimumBid) external onlyOwner {
        uint256 oldMinimum = minimumBid;
        minimumBid = newMinimumBid;
        emit MinimumBidUpdated(oldMinimum, newMinimumBid);
    }
    
    /**
     * @notice Update registration deposit
     * @param newDeposit New registration deposit
     */
    function updateRegistrationDeposit(uint256 newDeposit) external onlyOwner {
        uint256 oldDeposit = registrationDeposit;
        registrationDeposit = newDeposit;
        emit RegistrationDepositUpdated(oldDeposit, newDeposit);
    }
    
    /**
     * @notice Open or close registration
     * @param open Whether registration should be open
     */
    function setRegistrationOpen(bool open) external onlyOwner {
        registrationOpen = open;
        emit RegistrationStatusChanged(open);
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
        if (token == address(0)) revert InvalidAmount();
        if (to == address(0)) revert InvalidAmount();
        
        IERC20(token).safeTransfer(to, amount);
    }
}