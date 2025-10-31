// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {NativeTransferPrecompileMock} from "../../src/mocks/NativeTransferPrecompileMock.sol";

import {ANDETokenDuality as ANDEToken} from "../../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../../src/staking/AndeNativeStaking.sol";
import {AndeVesting} from "../../src/tokenomics/AndeVesting.sol";
import {AndeSequencerRegistry} from "../../src/sequencer/AndeSequencerRegistry.sol";
import {AndeFeeDistributor} from "../../src/tokenomics/AndeFeeDistributor.sol";
import {CommunityTreasury} from "../../src/community/CommunityTreasury.sol";

/**
 * @title CoreIntegration
 * @notice Core integration tests for sovereign dual-token ecosystem
 * @dev Tests critical interactions between main contracts
 */
contract CoreIntegration is Test {
    // Contracts
    ANDEToken public andeToken;
    AndeNativeStaking public staking;
    AndeSequencerRegistry public sequencerRegistry;
    AndeFeeDistributor public feeDistributor;
    CommunityTreasury public treasury;

    // Actors
    address public owner = address(0x1);
    address public foundation = address(0x2);
    address public alice = address(0x3);
    address public bob = address(0x4);
    address public protocolTreasury = address(0x6);

    // Constants
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant NETWORK_FEES = 10_000e18;

    function setUp() public {
        vm.startPrank(owner);

        // Use MockERC20 for simplicity in integration tests
        // ANDETokenDuality requires complex precompile setup
        MockERC20 mockAnde = new MockERC20("ANDE", "ANDE", 18);
        mockAnde.mint(owner, TOTAL_SUPPLY);
        mockAnde.mint(alice, 1_000_000e18);
        mockAnde.mint(bob, 1_000_000e18);
        andeToken = ANDEToken(address(mockAnde));

        // Deploy Staking using MockERC20 for simplicity
        MockERC20 mockToken = new MockERC20("ANDE", "ANDE", 18);
        mockToken.mint(owner, TOTAL_SUPPLY);
        mockToken.mint(alice, 1_000_000e18);
        mockToken.mint(bob, 1_000_000e18);
        
        AndeNativeStaking stakingImpl = new AndeNativeStaking();
        bytes memory stakingInitData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(mockToken),
            owner,
            owner
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = AndeNativeStaking(address(stakingProxy));

        // Deploy Sequencer Registry
        AndeSequencerRegistry registryImpl = new AndeSequencerRegistry();
        bytes memory registryInitData = abi.encodeWithSelector(
            AndeSequencerRegistry.initialize.selector,
            owner,
            foundation
        );
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryImpl), registryInitData);
        sequencerRegistry = AndeSequencerRegistry(address(registryProxy));

        // Deploy Community Treasury FIRST
        CommunityTreasury treasuryImpl = new CommunityTreasury();
        bytes memory treasuryInitData = abi.encodeWithSelector(
            CommunityTreasury.initialize.selector,
            address(andeToken),
            owner
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInitData);
        treasury = CommunityTreasury(address(treasuryProxy));

        // Deploy Fee Distributor with treasury address
        AndeFeeDistributor distributorImpl = new AndeFeeDistributor();
        bytes memory distributorInitData = abi.encodeWithSelector(
            AndeFeeDistributor.initialize.selector,
            address(andeToken),
            address(sequencerRegistry),
            address(staking),
            protocolTreasury,
            address(treasury),
            owner
        );
        ERC1967Proxy distributorProxy = new ERC1967Proxy(address(distributorImpl), distributorInitData);
        feeDistributor = AndeFeeDistributor(address(distributorProxy));

        // Fund accounts
        andeToken.transfer(alice, 1_000_000e18);
        andeToken.transfer(bob, 1_000_000e18);

        vm.stopPrank();
    }

    // ============================================
    // TEST 1: Fee Distribution Flow
    // ============================================
    
    function testFeeDistributionFlow() public {
        // Collect network fees
        vm.startPrank(owner);
        andeToken.approve(address(feeDistributor), NETWORK_FEES);
        feeDistributor.collectFees(NETWORK_FEES);
        vm.stopPrank();

        // Get balances before distribution
        uint256 stakingBefore = andeToken.balanceOf(address(staking));
        uint256 sequencerBefore = andeToken.balanceOf(address(sequencerRegistry));
        uint256 protocolBefore = andeToken.balanceOf(protocolTreasury);
        uint256 communityBefore = andeToken.balanceOf(address(treasury));

        // Distribute fees
        feeDistributor.distributeFees();

        // Verify distribution (40/30/20/10 split)
        uint256 stakingShare = NETWORK_FEES * 3000 / 10000; // 30%
        uint256 sequencerShare = NETWORK_FEES * 4000 / 10000; // 40%
        uint256 protocolShare = NETWORK_FEES * 2000 / 10000; // 20%
        uint256 communityShare = NETWORK_FEES * 1000 / 10000; // 10%

        assertEq(andeToken.balanceOf(address(staking)) - stakingBefore, stakingShare);
        assertEq(andeToken.balanceOf(address(sequencerRegistry)) - sequencerBefore, sequencerShare);
        assertEq(andeToken.balanceOf(protocolTreasury) - protocolBefore, protocolShare);
        assertEq(andeToken.balanceOf(address(treasury)) - communityBefore, communityShare);

        console.log("Fee distribution successful");
        // console.log removed
        // console.log removed
        // console.log removed
        // console.log removed
    }

    // ============================================
    // TEST 2: Sequencer Block Production
    // ============================================
    
    function testSequencerBlockProduction() public {
        // Verify genesis sequencer
        assertEq(sequencerRegistry.getActiveSequencersCount(), 1);
        
        address[] memory sequencers = sequencerRegistry.getActiveSequencers();
        assertEq(sequencers[0], foundation);

        // Record blocks
        vm.startPrank(owner);
        for (uint i = 0; i < 10; i++) {
            sequencerRegistry.recordBlockProduced(foundation);
        }
        vm.stopPrank();

        // Verify blocks recorded
        AndeSequencerRegistry.SequencerInfo memory info = 
            sequencerRegistry.getSequencerInfo(foundation);
        
        assertEq(info.totalBlocksProduced, 10);
        assertTrue(info.isActive);

        // console.log removed
    }

    // ============================================
    // TEST 3: Treasury Grant Flow
    // ============================================
    
    function testTreasuryGrantFlow() public {
        // Fund treasury
        vm.startPrank(owner);
        andeToken.approve(address(treasury), 100_000e18);
        treasury.receiveFunds(100_000e18);
        vm.stopPrank();

        // Propose grant
        vm.prank(owner);
        uint256 grantId = treasury.proposeGrant(
            alice,
            10_000e18,
            "Test Grant",
            "Description",
            "QmHash",
            CommunityTreasury.GrantCategory.BUILDER_GRANT
        );

        // Setup voter
        vm.startPrank(owner);
        andeToken.transfer(bob, 10_000e18);
        treasury.grantRole(treasury.GRANT_APPROVER_ROLE(), bob);
        vm.stopPrank();

        // Vote and finalize
        vm.prank(bob);
        treasury.voteOnGrant(grantId, true);

        vm.prank(owner);
        treasury.finalizeGrant(grantId);

        // Disburse
        uint256 aliceBefore = andeToken.balanceOf(alice);
        vm.prank(owner);
        treasury.disburseGrant(grantId);

        assertEq(andeToken.balanceOf(alice) - aliceBefore, 10_000e18);

        console.log("Grant disbursed successfully");
    }

    // ============================================
    // TEST 4: Multi-Epoch Fee Distribution
    // ============================================
    
    function testMultiEpochDistribution() public {
        // Epoch 0
        vm.startPrank(owner);
        andeToken.approve(address(feeDistributor), NETWORK_FEES * 5);
        feeDistributor.collectFees(NETWORK_FEES);
        vm.stopPrank();
        
        feeDistributor.distributeFees();

        // End epoch
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        feeDistributor.endEpoch();

        // Epoch 1
        vm.startPrank(owner);
        feeDistributor.collectFees(NETWORK_FEES * 2);
        vm.stopPrank();
        
        feeDistributor.distributeFees();

        // Verify epochs
        assertEq(feeDistributor.currentEpoch(), 1);

        AndeFeeDistributor.EpochStats memory epoch0 = feeDistributor.getEpochStats(0);
        assertEq(epoch0.totalFeesCollected, NETWORK_FEES);
        
        AndeFeeDistributor.EpochStats memory epoch1 = feeDistributor.getCurrentEpochStats();
        assertEq(epoch1.totalFeesCollected, NETWORK_FEES * 2);

        console.log("Multi-epoch distribution successful");
    }

    // ============================================
    // TEST 5: Phase Transition
    // ============================================
    
    function testPhaseTransition() public {
        // Start in GENESIS
        assertEq(uint(sequencerRegistry.currentPhase()), uint(AndeSequencerRegistry.Phase.GENESIS));

        // Record blocks
        vm.startPrank(owner);
        for (uint i = 0; i < 50; i++) {
            sequencerRegistry.recordBlockProduced(foundation);
        }
        vm.stopPrank();

        // Transition to DUAL
        vm.warp(block.timestamp + 180 days);
        vm.prank(owner);
        sequencerRegistry.transitionPhase();

        assertEq(uint(sequencerRegistry.currentPhase()), uint(AndeSequencerRegistry.Phase.DUAL));

        console.log("Phase transition successful");
    }

    // ============================================
    // TEST 6: Emergency Pause
    // ============================================
    
    function testEmergencyPause() public {
        // Grant pauser roles
        vm.startPrank(owner);
        feeDistributor.grantRole(feeDistributor.PAUSER_ROLE(), owner);
        treasury.grantRole(treasury.PAUSER_ROLE(), owner);
        
        // Pause
        feeDistributor.pause();
        treasury.pause();
        vm.stopPrank();

        // Verify paused
        assertTrue(feeDistributor.paused());
        assertTrue(treasury.paused());

        // Operations should fail
        vm.startPrank(owner);
        andeToken.approve(address(feeDistributor), NETWORK_FEES);
        vm.expectRevert();
        feeDistributor.collectFees(NETWORK_FEES);
        vm.stopPrank();

        // Unpause
        vm.startPrank(owner);
        feeDistributor.unpause();
        treasury.unpause();
        vm.stopPrank();

        // Should work now
        vm.startPrank(owner);
        feeDistributor.collectFees(NETWORK_FEES);
        vm.stopPrank();

        console.log("Emergency pause/unpause successful");
    }

    // ============================================
    // TEST 7: Complete Integration Flow
    // ============================================
    
    function testCompleteIntegrationFlow() public {
        console.log("=== Starting Complete Integration Test ===");

        // 1. Sequencer produces blocks
        vm.startPrank(owner);
        for (uint i = 0; i < 20; i++) {
            sequencerRegistry.recordBlockProduced(foundation);
        }
        vm.stopPrank();

        // 2. Network collects fees
        vm.startPrank(owner);
        andeToken.approve(address(feeDistributor), NETWORK_FEES * 3);
        for (uint i = 0; i < 3; i++) {
            feeDistributor.collectFees(NETWORK_FEES);
        }
        vm.stopPrank();

        // 3. Distribute fees
        uint256 totalFees = NETWORK_FEES * 3;
        feeDistributor.distributeFees();

        // 4. Verify all distributions
        uint256 expectedStaking = totalFees * 3000 / 10000;
        uint256 expectedSequencer = totalFees * 4000 / 10000;
        uint256 expectedProtocol = totalFees * 2000 / 10000;
        uint256 expectedCommunity = totalFees * 1000 / 10000;

        assertEq(andeToken.balanceOf(address(staking)), expectedStaking);
        assertEq(andeToken.balanceOf(address(sequencerRegistry)), expectedSequencer);
        assertEq(andeToken.balanceOf(protocolTreasury), expectedProtocol);
        assertEq(andeToken.balanceOf(address(treasury)), expectedCommunity);

        // 4b. Treasury needs to call receiveFunds to update availableFunds tracking
        vm.startPrank(address(treasury));
        andeToken.approve(address(treasury), expectedCommunity);
        vm.stopPrank();
        
        vm.prank(address(treasury));
        treasury.receiveFunds(expectedCommunity);

        // 5. Community treasury proposes grant from collected fees (3K ANDE available, so ask for 2K)
        vm.prank(owner);
        uint256 grantId = treasury.proposeGrant(
            alice,
            2_000e18,
            "Ecosystem Grant",
            "Building tools",
            "QmHash",
            CommunityTreasury.GrantCategory.BUILDER_GRANT
        );

        // 6. Grant is voted and disbursed
        vm.startPrank(owner);
        andeToken.transfer(bob, 10_000e18);
        treasury.grantRole(treasury.GRANT_APPROVER_ROLE(), bob);
        vm.stopPrank();

        vm.prank(bob);
        treasury.voteOnGrant(grantId, true);

        vm.prank(owner);
        treasury.finalizeGrant(grantId);

        uint256 aliceBefore = andeToken.balanceOf(alice);
        vm.prank(owner);
        treasury.disburseGrant(grantId);

        assertEq(andeToken.balanceOf(alice) - aliceBefore, 2_000e18);

        // console.log removed
        // console.log removed
        // console.log removed
        // console.log removed
    }
}
