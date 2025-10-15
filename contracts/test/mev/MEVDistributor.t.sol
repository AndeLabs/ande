// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/mev/MEVDistributor.sol";
import "../../src/ANDEToken.sol";
import "../../src/gauges/VotingEscrow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MEVDistributorTest
 * @notice Comprehensive test suite for MEVDistributor contract
 */
contract MEVDistributorTest is Test {
    // ========================================
    // TEST STATE
    // ========================================
    
    MEVDistributor public mevDistributor;
    ANDEToken public andeToken;
    VotingEscrow public votingEscrow;
    
    // Test addresses
    address public owner = address(0x1);
    address public sequencer = address(0x2);
    address public treasury = address(0x3);
    address public protocolFeeCollector = address(0x4);
    address public user1 = address(0x5);
    address public user2 = address(0x6);
    
    // Test constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant USER_LOCK_AMOUNT = 1000 ether;
    uint256 public constant LOCK_DURATION = 365 days;
    uint256 public constant MEV_AMOUNT = 100 ether;
    uint256 public constant EPOCH_DURATION = 7 days;
    
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
        andeToken.mint(user1, INITIAL_SUPPLY);
        andeToken.mint(user2, INITIAL_SUPPLY);
        andeToken.mint(sequencer, INITIAL_SUPPLY);
        
        // Deploy VotingEscrow
        votingEscrow = new VotingEscrow(
            address(andeToken),
            "veANDE",
            "veANDE",
            "1.0.0"
        );
        
        // Deploy MEVDistributor
        mevDistributor = new MEVDistributor(
            address(votingEscrow),
            address(andeToken),
            treasury,
            protocolFeeCollector,
            sequencer
        );
        
        // Approve tokens for users
        vm.startPrank(user1);
        andeToken.approve(address(votingEscrow), USER_LOCK_AMOUNT);
        andeToken.approve(address(mevDistributor), MEV_AMOUNT);
        
        vm.startPrank(user2);
        andeToken.approve(address(votingEscrow), USER_LOCK_AMOUNT);
        andeToken.approve(address(mevDistributor), MEV_AMOUNT);
        
        vm.startPrank(sequencer);
        andeToken.approve(address(mevDistributor), MEV_AMOUNT * 100);
        
        vm.stopPrank();
        
        // Create veANDE locks for users
        vm.startPrank(user1);
        votingEscrow.create_lock(USER_LOCK_AMOUNT, block.timestamp + LOCK_DURATION);
        
        vm.startPrank(user2);
        votingEscrow.create_lock(USER_LOCK_AMOUNT, block.timestamp + LOCK_DURATION);
        
        vm.stopPrank();
    }
    
    // ========================================
    // CONSTRUCTOR TESTS
    // ========================================
    
    function testConstructor() public {
        assertEq(address(mevDistributor.votingEscrow()), address(votingEscrow));
        assertEq(address(mevDistributor.andeToken()), address(andeToken));
        assertEq(mevDistributor.treasury(), treasury);
        assertEq(mevDistributor.protocolFeeCollector(), protocolFeeCollector);
        assertEq(mevDistributor.sequencer(), sequencer);
        assertEq(mevDistributor.currentEpoch(), 1);
        assertEq(mevDistributor.epochStartTime(), block.timestamp);
        assertFalse(mevDistributor.mevCapturePaused());
    }
    
    function testConstructorZeroAddress() public {
        vm.expectRevert();
        new MEVDistributor(
            address(0),
            address(andeToken),
            treasury,
            protocolFeeCollector,
            sequencer
        );
    }
    
    // ========================================
    // DEPOSIT MEV TESTS
    // ========================================
    
    function testDepositMEV() public {
        uint256 initialBalance = andeToken.balanceOf(address(mevDistributor));
        
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        assertEq(andeToken.balanceOf(address(mevDistributor)), initialBalance + MEV_AMOUNT);
        
        (uint256 totalMEV,,,,,) = mevDistributor.getEpochData(1);
        assertEq(totalMEV, MEV_AMOUNT);
    }
    
    function testDepositMEVOnlySequencer() public {
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.OnlySequencer.selector));
        vm.startPrank(user1);
        mevDistributor.depositMEV(MEV_AMOUNT);
    }
    
    function testDepositMEVZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.AmountMustBePositive.selector));
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(0);
    }
    
    function testDepositMEVWhenPaused() public {
        vm.startPrank(owner);
        mevDistributor.setMEVCapturePaused(true);
        
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.MEVCaptureIsPaused.selector));
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
    }
    
    // ========================================
    // EPOCH SETTLEMENT TESTS
    // ========================================
    
    function testSettleEpoch() public {
        // Deposit MEV first
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        // Fast forward to end of epoch
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        
        // Settle epoch
        mevDistributor.settleEpoch();
        
        // Check epoch was settled
        (,,,, bool settled,) = mevDistributor.getEpochData(1);
        assertTrue(settled);
        
        // Check new epoch started
        assertEq(mevDistributor.currentEpoch(), 2);
        
        // Check distribution amounts
        (uint256 totalMEV, uint256 stakersReward, uint256 protocolFee, uint256 treasuryAmount,,) = 
            mevDistributor.getEpochData(1);
        
        assertEq(totalMEV, MEV_AMOUNT);
        assertEq(stakersReward, (MEV_AMOUNT * 8000) / 10000); // 80%
        assertEq(protocolFee, (MEV_AMOUNT * 1500) / 10000); // 15%
        assertEq(treasuryAmount, (MEV_AMOUNT * 500) / 10000); // 5%
    }
    
    function testSettleEpochTooEarly() public {
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.EpochNotFinished.selector));
        mevDistributor.settleEpoch();
    }
    
    // ========================================
    // REWARDS CLAIMING TESTS
    // ========================================
    
    function testClaimRewards() public {
        // Deposit MEV and settle epoch
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        mevDistributor.settleEpoch();
        
        // Get epoch data to calculate actual expected rewards
        (uint256 totalMEV, uint256 stakersReward,,,, uint256 epochTimestamp) = mevDistributor.getEpochData(1);
        
        // Get user's actual voting power at epoch end
        uint256 user1VotingPower = votingEscrow.balanceOfAt(user1, epochTimestamp);
        uint256 totalVotingPower = votingEscrow.totalSupplyAt(epochTimestamp);
        
        // Calculate expected reward based on actual voting power
        uint256 expectedReward = (stakersReward * user1VotingPower) / totalVotingPower;
        
        // Claim rewards
        uint256 initialBalance = andeToken.balanceOf(user1);
        vm.startPrank(user1);
        mevDistributor.claimRewards(1);
        
        uint256 finalBalance = andeToken.balanceOf(user1);
        assertEq(finalBalance - initialBalance, expectedReward);
        
        // Check claim data
        (uint256 lastClaimedEpoch, uint256 totalClaimed) = mevDistributor.userClaims(user1);
        assertEq(lastClaimedEpoch, 1);
        assertEq(totalClaimed, expectedReward);
    }
    
    function testClaimRewardsNothingToClaim() public {
        // Deposit MEV and settle epoch so we can move to epoch 2
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        mevDistributor.settleEpoch();
        
        // Now try to claim again (user has already claimed or has no more to claim)
        vm.startPrank(user1);
        mevDistributor.claimRewards(1); // First claim succeeds
        
        // Second claim of same epoch should fail with NothingToClaim
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.NothingToClaim.selector));
        mevDistributor.claimRewards(1);
    }
    
    function testClaimRewardsCurrentEpoch() public {
        vm.expectRevert(abi.encodeWithSelector(MEVDistributor.CannotClaimCurrentEpoch.selector));
        vm.startPrank(user1);
        mevDistributor.claimRewards(1);
    }
    
    // ========================================
    // PENDING REWARDS TESTS
    // ========================================
    
    function testPendingRewards() public {
        // Deposit MEV and settle epoch
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        mevDistributor.settleEpoch();
        
        // Get epoch data to calculate actual expected rewards
        (uint256 totalMEV, uint256 stakersReward,,,, uint256 epochTimestamp) = mevDistributor.getEpochData(1);
        
        // Get user's actual voting power at epoch end
        uint256 user1VotingPower = votingEscrow.balanceOfAt(user1, epochTimestamp);
        uint256 totalVotingPower = votingEscrow.totalSupplyAt(epochTimestamp);
        
        // Calculate expected reward based on actual voting power
        uint256 expectedReward = (stakersReward * user1VotingPower) / totalVotingPower;
        
        // Check pending rewards
        uint256 pending = mevDistributor.pendingRewards(user1, 1);
        assertEq(pending, expectedReward);
    }
    
    // ========================================
    // ADMIN FUNCTIONS TESTS
    // ========================================
    
    function testUpdateSequencer() public {
        address newSequencer = address(0x7);
        
        vm.startPrank(owner);
        mevDistributor.updateSequencer(newSequencer);
        
        assertEq(mevDistributor.sequencer(), newSequencer);
    }
    
    function testUpdateSequencerNotOwner() public {
        vm.expectRevert();
        vm.startPrank(user1);
        mevDistributor.updateSequencer(address(0x7));
    }
    
    function testUpdateSequencerZeroAddress() public {
        vm.expectRevert();
        vm.startPrank(owner);
        mevDistributor.updateSequencer(address(0));
    }
    
    function testSetMEVCapturePaused() public {
        vm.startPrank(owner);
        mevDistributor.setMEVCapturePaused(true);
        assertTrue(mevDistributor.mevCapturePaused());
        
        mevDistributor.setMEVCapturePaused(false);
        assertFalse(mevDistributor.mevCapturePaused());
    }
    
    // ========================================
    // VIEW FUNCTIONS TESTS
    // ========================================
    
    function testGetCurrentEpochInfo() public {
        (uint256 epoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = 
            mevDistributor.getCurrentEpochInfo();
        
        assertEq(epoch, 1);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + EPOCH_DURATION);
        assertEq(timeRemaining, EPOCH_DURATION);
    }
    
    function testGetEpochData() public {
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        (uint256 totalMEV, uint256 stakersReward, uint256 protocolFee, uint256 treasuryAmount, bool settled, uint256 timestamp) = 
            mevDistributor.getEpochData(1);
        
        assertEq(totalMEV, MEV_AMOUNT);
        assertEq(stakersReward, 0); // Not settled yet
        assertEq(protocolFee, 0); // Not settled yet
        assertEq(treasuryAmount, 0); // Not settled yet
        assertFalse(settled);
        assertEq(timestamp, 0); // Not settled yet
    }
    
    // ========================================
    // FUZZ TESTS
    // ========================================
    
    function testFuzzDepositMEV(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);
        
        uint256 initialBalance = andeToken.balanceOf(address(mevDistributor));
        
        vm.startPrank(sequencer);
        andeToken.approve(address(mevDistributor), amount);
        mevDistributor.depositMEV(amount);
        
        assertEq(andeToken.balanceOf(address(mevDistributor)), initialBalance + amount);
    }
    
    // ========================================
    // INTEGRATION TESTS
    // ========================================
    
    function testFullMEVFlow() public {
        // 1. Deposit MEV
        vm.startPrank(sequencer);
        mevDistributor.depositMEV(MEV_AMOUNT);
        
        // 2. Wait for epoch to end
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        
        // Record balances before settlement
        uint256 protocolBalanceBefore = andeToken.balanceOf(protocolFeeCollector);
        uint256 treasuryBalanceBefore = andeToken.balanceOf(treasury);
        
        // 3. Settle epoch
        mevDistributor.settleEpoch();
        
        // 4. Verify protocol and treasury received their shares
        assertEq(
            andeToken.balanceOf(protocolFeeCollector) - protocolBalanceBefore,
            (MEV_AMOUNT * 1500) / 10000
        );
        assertEq(
            andeToken.balanceOf(treasury) - treasuryBalanceBefore,
            (MEV_AMOUNT * 500) / 10000
        );
        
        // Get epoch data to calculate actual expected rewards
        (uint256 totalMEV, uint256 stakersReward,,,, uint256 epochTimestamp) = mevDistributor.getEpochData(1);
        
        // Get users' actual voting power at epoch end
        uint256 user1VotingPower = votingEscrow.balanceOfAt(user1, epochTimestamp);
        uint256 user2VotingPower = votingEscrow.balanceOfAt(user2, epochTimestamp);
        uint256 totalVotingPower = votingEscrow.totalSupplyAt(epochTimestamp);
        
        // 5. Users claim rewards
        uint256 user1BalanceBefore = andeToken.balanceOf(user1);
        uint256 user2BalanceBefore = andeToken.balanceOf(user2);
        
        vm.startPrank(user1);
        mevDistributor.claimRewards(1);
        
        vm.startPrank(user2);
        mevDistributor.claimRewards(1);
        
        // Verify users received their shares based on actual voting power
        uint256 expectedUser1Reward = (stakersReward * user1VotingPower) / totalVotingPower;
        uint256 expectedUser2Reward = (stakersReward * user2VotingPower) / totalVotingPower;
        
        assertEq(andeToken.balanceOf(user1) - user1BalanceBefore, expectedUser1Reward);
        assertEq(andeToken.balanceOf(user2) - user2BalanceBefore, expectedUser2Reward);
    }
}