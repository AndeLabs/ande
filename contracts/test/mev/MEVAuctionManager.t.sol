// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/mev/MEVAuctionManager.sol";
import "../../src/ANDEToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MEVAuctionManagerTest
 * @notice Comprehensive test suite for MEVAuctionManager contract
 */
contract MEVAuctionManagerTest is Test {
    // ========================================
    // TEST STATE
    // ========================================
    
    MEVAuctionManager public mevAuctionManager;
    ANDEToken public andeToken;
    
    // Test addresses
    address public owner = address(0x1);
    address public sequencer = address(0x2);
    address public searcher1 = address(0x3);
    address public searcher2 = address(0x4);
    address public searcher3 = address(0x5);
    
    // Test constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant MINIMUM_BID = 0.1 ether;
    uint256 public constant REGISTRATION_DEPOSIT = 1 ether;
    uint256 public constant BID_AMOUNT = 1 ether;
    uint256 public constant TARGET_BLOCK_OFFSET = 2;
    
    // ========================================
    // SETUP
    // ========================================
    
    function setUp() public {
        // Deploy ANDE token with proxy pattern
        vm.startPrank(owner);
        ANDEToken implementation = new ANDEToken();
        bytes memory data = abi.encodeWithSelector(ANDEToken.initialize.selector, owner, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        andeToken = ANDEToken(address(proxy));
        
        // Mint tokens for testing
        andeToken.mint(searcher1, INITIAL_SUPPLY);
        andeToken.mint(searcher2, INITIAL_SUPPLY);
        andeToken.mint(searcher3, INITIAL_SUPPLY);
        
        // Deploy MEVAuctionManager
        mevAuctionManager = new MEVAuctionManager(
            address(andeToken),
            sequencer,
            MINIMUM_BID,
            REGISTRATION_DEPOSIT
        );
        
        // Approve tokens for searchers
        vm.startPrank(searcher1);
        andeToken.approve(address(mevAuctionManager), INITIAL_SUPPLY);
        
        vm.startPrank(searcher2);
        andeToken.approve(address(mevAuctionManager), INITIAL_SUPPLY);
        
        vm.startPrank(searcher3);
        andeToken.approve(address(mevAuctionManager), INITIAL_SUPPLY);
        
        vm.stopPrank();
    }
    
    // ========================================
    // CONSTRUCTOR TESTS
    // ========================================
    
    function testConstructor() public {
        assertEq(address(mevAuctionManager.andeToken()), address(andeToken));
        assertEq(mevAuctionManager.sequencer(), sequencer);
        assertEq(mevAuctionManager.minimumBid(), MINIMUM_BID);
        assertEq(mevAuctionManager.registrationDeposit(), REGISTRATION_DEPOSIT);
        assertTrue(mevAuctionManager.registrationOpen());
    }
    
    function testConstructorZeroAddress() public {
        vm.expectRevert();
        new MEVAuctionManager(
            address(0),
            sequencer,
            MINIMUM_BID,
            REGISTRATION_DEPOSIT
        );
    }
    
    // ========================================
    // SEARCHER REGISTRATION TESTS
    // ========================================
    
    function testRegisterSearcher() public {
        uint256 initialBalance = andeToken.balanceOf(searcher1);
        uint256 contractBalance = andeToken.balanceOf(address(mevAuctionManager));
        
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        // Check registration
        assertTrue(mevAuctionManager.registeredSearchers(searcher1));
        assertEq(mevAuctionManager.registrationDeposits(searcher1), REGISTRATION_DEPOSIT);
        
        // Check token transfer
        assertEq(andeToken.balanceOf(searcher1), initialBalance - REGISTRATION_DEPOSIT);
        assertEq(andeToken.balanceOf(address(mevAuctionManager)), contractBalance + REGISTRATION_DEPOSIT);
    }
    
    function testRegisterSearcherAlreadyRegistered() public {
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.AlreadyRegistered.selector));
        mevAuctionManager.registerSearcher();
    }
    
    function testRegisterSearcherRegistrationClosed() public {
        vm.startPrank(owner);
        mevAuctionManager.setRegistrationOpen(false);
        
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.RegistrationClosed.selector));
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
    }
    
    function testUnregisterSearcher() public {
        // Register first
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        uint256 initialBalance = andeToken.balanceOf(searcher1);
        uint256 contractBalance = andeToken.balanceOf(address(mevAuctionManager));
        
        // Unregister
        mevAuctionManager.unregisterSearcher();
        
        // Check unregistration
        assertFalse(mevAuctionManager.registeredSearchers(searcher1));
        assertEq(mevAuctionManager.registrationDeposits(searcher1), 0);
        
        // Check deposit refund
        assertEq(andeToken.balanceOf(searcher1), initialBalance + REGISTRATION_DEPOSIT);
        assertEq(andeToken.balanceOf(address(mevAuctionManager)), contractBalance - REGISTRATION_DEPOSIT);
    }
    
    function testUnregisterSearcherNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.NotRegistered.selector));
        vm.startPrank(searcher1);
        mevAuctionManager.unregisterSearcher();
    }
    
    // ========================================
    // BUNDLE SUBMISSION TESTS
    // ========================================
    
    function testSubmitBundle() public {
        // Register searcher first
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        bytes32 bundleHash = keccak256("test_bundle");
        
        uint256 initialBalance = andeToken.balanceOf(searcher1);
        uint256 contractBalance = andeToken.balanceOf(address(mevAuctionManager));
        
        // Submit bundle
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        // Check bundle data
        MEVAuctionManager.Bundle memory bundle = mevAuctionManager.getBundle(bundleHash);
        assertEq(bundle.bundleHash, bundleHash);
        assertEq(bundle.searcher, searcher1);
        assertEq(bundle.bidAmount, BID_AMOUNT);
        assertEq(bundle.blockNumber, targetBlock);
        assertFalse(bundle.executed);
        assertEq(bundle.timestamp, block.timestamp);
        
        // Check token transfer
        assertEq(andeToken.balanceOf(searcher1), initialBalance - BID_AMOUNT);
        assertEq(andeToken.balanceOf(address(mevAuctionManager)), contractBalance + BID_AMOUNT);
        
        // Check block bundles
        bytes32[] memory blockBundles = mevAuctionManager.getBlockBundles(targetBlock);
        assertEq(blockBundles.length, 1);
        assertEq(blockBundles[0], bundleHash);
        
        // Check searcher stats
        assertEq(mevAuctionManager.searcherBundleCount(searcher1), 1);
    }
    
    function testSubmitBundleNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.NotRegistered.selector));
        vm.startPrank(searcher1);
        mevAuctionManager.submitBundle(keccak256("test"), BID_AMOUNT, block.number + 1);
    }
    
    function testSubmitBundleInsufficientBid() public {
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.InvalidAmount.selector));
        mevAuctionManager.submitBundle(keccak256("test"), MINIMUM_BID - 1, block.number + 1);
    }
    
    function testSubmitBundleInvalidBlockNumber() public {
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.InvalidBlockNumber.selector));
        mevAuctionManager.submitBundle(keccak256("test"), BID_AMOUNT, block.number);
    }
    
    function testSubmitBundleAlreadyExists() public {
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        
        // Submit first time
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        // Try to submit same bundle again
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.BundleAlreadyExists.selector));
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
    }
    
    // ========================================
    // BUNDLE EXECUTION TESTS
    // ========================================
    
    function testMarkBundleExecuted() public {
        // Register and submit bundle
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        uint256 mevCaptured = 10 ether;
        uint256 bidPaid = BID_AMOUNT;
        
        uint256 initialOwnerBalance = andeToken.balanceOf(owner);
        uint256 initialSearcherBalance = andeToken.balanceOf(searcher1);
        
        // Mark as executed by sequencer
        vm.startPrank(sequencer);
        mevAuctionManager.markBundleExecuted(bundleHash, mevCaptured, bidPaid);
        
        // Check bundle state
        MEVAuctionManager.Bundle memory bundle = mevAuctionManager.getBundle(bundleHash);
        assertTrue(bundle.executed);
        assertEq(bundle.mevCaptured, mevCaptured);
        
        // Check searcher stats
        assertEq(mevAuctionManager.searcherMEVCaptured(searcher1), mevCaptured);
        
        // Check token transfers (bid paid to owner)
        assertEq(andeToken.balanceOf(owner), initialOwnerBalance + bidPaid);
        assertEq(andeToken.balanceOf(searcher1), initialSearcherBalance); // No refund since bidPaid == bidAmount
    }
    
    function testMarkBundleExecutedWithRefund() public {
        // Register and submit bundle
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        uint256 mevCaptured = 10 ether;
        uint256 bidPaid = BID_AMOUNT / 2; // Pay only half the bid
        
        uint256 initialSearcherBalance = andeToken.balanceOf(searcher1);
        
        // Mark as executed by sequencer
        vm.startPrank(sequencer);
        mevAuctionManager.markBundleExecuted(bundleHash, mevCaptured, bidPaid);
        
        // Check refund
        assertEq(andeToken.balanceOf(searcher1), initialSearcherBalance + (BID_AMOUNT - bidPaid));
    }
    
    function testMarkBundleExecutedNotSequencer() public {
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        vm.expectRevert(abi.encodeWithSelector(MEVAuctionManager.OnlySequencer.selector));
        vm.startPrank(searcher2);
        mevAuctionManager.markBundleExecuted(bundleHash, 10 ether, BID_AMOUNT);
    }
    
    function testMarkBundleRejected() public {
        // Register and submit bundle
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        uint256 initialSearcherBalance = andeToken.balanceOf(searcher1);
        
        // Mark as rejected by sequencer
        vm.startPrank(sequencer);
        mevAuctionManager.markBundleRejected(bundleHash, "Invalid bundle");
        
        // Check bundle state
        MEVAuctionManager.Bundle memory bundle = mevAuctionManager.getBundle(bundleHash);
        assertTrue(bundle.executed);
        assertEq(bundle.mevCaptured, 0);
        
        // Check full refund
        assertEq(andeToken.balanceOf(searcher1), initialSearcherBalance + BID_AMOUNT);
    }
    
    // ========================================
    // VIEW FUNCTIONS TESTS
    // ========================================
    
    function testGetSearcherStats() public {
        // Register and submit bundle
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        bytes32 bundleHash = keccak256("test_bundle");
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        mevAuctionManager.submitBundle(bundleHash, BID_AMOUNT, targetBlock);
        
        // Get stats
        MEVAuctionManager.SearcherStats memory stats = mevAuctionManager.getSearcherStats(searcher1);
        
        assertEq(stats.totalBundles, 1);
        assertEq(stats.executedBundles, 0); // Not executed yet
        assertEq(stats.totalMEVCaptured, 0);
        assertEq(stats.totalBidsPaid, BID_AMOUNT);
        assertTrue(stats.registered);
    }
    
    // ========================================
    // ADMIN FUNCTIONS TESTS
    // ========================================
    
    function testUpdateSequencer() public {
        address newSequencer = address(0x6);
        
        vm.startPrank(owner);
        mevAuctionManager.updateSequencer(newSequencer);
        
        assertEq(mevAuctionManager.sequencer(), newSequencer);
    }
    
    function testUpdateMinimumBid() public {
        uint256 newMinimumBid = 0.5 ether;
        
        vm.startPrank(owner);
        mevAuctionManager.updateMinimumBid(newMinimumBid);
        
        assertEq(mevAuctionManager.minimumBid(), newMinimumBid);
    }
    
    function testSetRegistrationOpen() public {
        vm.startPrank(owner);
        mevAuctionManager.setRegistrationOpen(false);
        assertFalse(mevAuctionManager.registrationOpen());
        
        mevAuctionManager.setRegistrationOpen(true);
        assertTrue(mevAuctionManager.registrationOpen());
    }
    
    function testForceUnregisterSearcher() public {
        // Register searcher
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        uint256 initialSearcherBalance = andeToken.balanceOf(searcher1);
        
        // Force unregister
        vm.startPrank(owner);
        mevAuctionManager.forceUnregisterSearcher(searcher1);
        
        // Check unregistration and refund
        assertFalse(mevAuctionManager.registeredSearchers(searcher1));
        assertEq(andeToken.balanceOf(searcher1), initialSearcherBalance + REGISTRATION_DEPOSIT);
    }
    
    // ========================================
    // INTEGRATION TESTS
    // ========================================
    
    function testFullAuctionFlow() public {
        // Register multiple searchers
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        vm.startPrank(searcher2);
        mevAuctionManager.registerSearcher();
        
        vm.startPrank(searcher3);
        mevAuctionManager.registerSearcher();
        
        // Submit bundles for same block
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        bytes32 bundle1 = keccak256("bundle1");
        bytes32 bundle2 = keccak256("bundle2");
        bytes32 bundle3 = keccak256("bundle3");
        
        vm.startPrank(searcher1);
        mevAuctionManager.submitBundle(bundle1, BID_AMOUNT, targetBlock);
        
        vm.startPrank(searcher2);
        mevAuctionManager.submitBundle(bundle2, BID_AMOUNT * 2, targetBlock);
        
        vm.startPrank(searcher3);
        mevAuctionManager.submitBundle(bundle3, BID_AMOUNT * 3, targetBlock);
        
        // Check block bundles
        bytes32[] memory blockBundles = mevAuctionManager.getBlockBundles(targetBlock);
        assertEq(blockBundles.length, 3);
        
        // Execute highest bidder (bundle3)
        uint256 mevCaptured = 15 ether;
        uint256 bidPaid = BID_AMOUNT * 2; // Second-price auction
        
        vm.startPrank(sequencer);
        mevAuctionManager.markBundleExecuted(bundle3, mevCaptured, bidPaid);
        
        // Reject other bundles
        mevAuctionManager.markBundleRejected(bundle1, "Outbid");
        mevAuctionManager.markBundleRejected(bundle2, "Outbid");
        
        // Check final state
        assertEq(mevAuctionManager.searcherMEVCaptured(searcher3), mevCaptured);
        assertEq(mevAuctionManager.searcherMEVCaptured(searcher1), 0);
        assertEq(mevAuctionManager.searcherMEVCaptured(searcher2), 0);
        
        // Check bundle states
        assertTrue(mevAuctionManager.getBundle(bundle1).executed);
        assertTrue(mevAuctionManager.getBundle(bundle2).executed);
        assertTrue(mevAuctionManager.getBundle(bundle3).executed);
    }
    
    // ========================================
    // FUZZ TESTS
    // ========================================
    
    function testFuzzSubmitBundle(uint256 bidAmount) public {
        // Account for registration deposit
        vm.assume(bidAmount >= MINIMUM_BID && bidAmount <= (INITIAL_SUPPLY - REGISTRATION_DEPOSIT));
        
        vm.startPrank(searcher1);
        mevAuctionManager.registerSearcher();
        
        bytes32 bundleHash = keccak256(abi.encodePacked(bidAmount));
        uint256 targetBlock = block.number + TARGET_BLOCK_OFFSET;
        
        andeToken.approve(address(mevAuctionManager), bidAmount);
        mevAuctionManager.submitBundle(bundleHash, bidAmount, targetBlock);
        
        MEVAuctionManager.Bundle memory bundle = mevAuctionManager.getBundle(bundleHash);
        assertEq(bundle.bidAmount, bidAmount);
    }
}