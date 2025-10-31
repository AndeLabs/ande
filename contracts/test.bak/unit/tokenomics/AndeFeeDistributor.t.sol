// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeFeeDistributor} from "../../../src/tokenomics/AndeFeeDistributor.sol";
import {ANDETokenDuality as ANDEToken} from "../../../src/ANDETokenDuality.sol";
import {NativeTransferPrecompileMock} from "../../../src/mocks/NativeTransferPrecompileMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ANDETokenTestHelper} from "../../helpers/ANDETokenTestHelper.sol";

contract AndeFeeDistributorTest is Test, ANDETokenTestHelper {
    AndeFeeDistributor public distributor;
    ANDEToken public andeToken;
    NativeTransferPrecompileMock public precompile;
    
    address public owner = address(0x1);
    address public sequencerRegistry = address(0x2);
    address public stakingContract = address(0x3);
    address public protocolTreasury = address(0x4);
    address public communityTreasury = address(0x5);
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18; // 1B ANDE
    uint256 public constant FEE_AMOUNT = 10000e18; // 10K ANDE fee
    
    event FeesCollected(address indexed from, uint256 amount, uint256 epoch);
    event FeesDistributed(
        uint256 indexed epoch,
        uint256 sequencerFees,
        uint256 stakersFees,
        uint256 protocolFees,
        uint256 communityTreasuryFees
    );
    event DistributionConfigUpdated(
        uint256 sequencerShare,
        uint256 stakersShare,
        uint256 protocolShare,
        uint256 communityTreasuryShare
    );
    event EpochEnded(uint256 indexed epoch, uint256 totalFees);

    function setUp() public {
        (andeToken, precompile) = deployANDETokenWithSupply(owner, owner, TOTAL_SUPPLY);
        
        vm.startPrank(owner);
        
        AndeFeeDistributor distributorImpl = new AndeFeeDistributor();
        bytes memory distributorInitData = abi.encodeWithSelector(
            AndeFeeDistributor.initialize.selector,
            address(andeToken),
            sequencerRegistry,
            stakingContract,
            protocolTreasury,
            communityTreasury,
            owner
        );
        ERC1967Proxy distributorProxy = new ERC1967Proxy(address(distributorImpl), distributorInitData);
        distributor = AndeFeeDistributor(address(distributorProxy));
        
        andeToken.transfer(address(distributor), FEE_AMOUNT * 10);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(distributor.hasRole(distributor.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(address(distributor.andeToken()), address(andeToken));
        assertEq(distributor.sequencerRegistry(), sequencerRegistry);
        assertEq(distributor.stakingContract(), stakingContract);
        assertEq(distributor.protocolTreasury(), protocolTreasury);
        assertEq(distributor.communityTreasury(), communityTreasury);
        assertEq(distributor.totalFeesCollected(), 0);
        assertEq(distributor.currentEpoch(), 0);
    }

    function testDistributionConfig() public {
        AndeFeeDistributor.FeeDistributionConfig memory config = distributor.getDistributionConfig();
        
        // Check default distribution (40/30/20/10)
        assertEq(config.sequencerShare, 4000); // 40%
        assertEq(config.stakersShare, 3000);   // 30%
        assertEq(config.protocolShare, 2000);  // 20%
        assertEq(config.communityTreasuryShare, 1000); // 10%
    }

    function testCollectFees() public {
        vm.startPrank(owner);
        
        // Approve tokens first
        andeToken.approve(address(distributor), FEE_AMOUNT);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit FeesCollected(owner, FEE_AMOUNT, 0);
        
        // Collect fees
        distributor.collectFees(FEE_AMOUNT);
        
        vm.stopPrank();
        
        // Verify fees collected
        assertEq(distributor.totalFeesCollected(), FEE_AMOUNT);
        
        // Check epoch stats
        AndeFeeDistributor.EpochStats memory stats = distributor.getCurrentEpochStats();
        assertEq(stats.totalFeesCollected, FEE_AMOUNT);
    }

    function testCollectFeesUnauthorized() public {
        vm.expectRevert();
        distributor.collectFees(FEE_AMOUNT);
    }

    function testDistributeFees() public {
        // Collect fees first
        vm.startPrank(owner);
        andeToken.approve(address(distributor), FEE_AMOUNT);
        distributor.collectFees(FEE_AMOUNT);
        vm.stopPrank();
        
        uint256 initialProtocolBalance = andeToken.balanceOf(protocolTreasury);
        uint256 initialCommunityBalance = andeToken.balanceOf(communityTreasury);
        uint256 initialSequencerBalance = andeToken.balanceOf(sequencerRegistry);
        uint256 initialStakingBalance = andeToken.balanceOf(stakingContract);
        
        // Expect event
        vm.expectEmit(true, false, false, false);
        emit FeesDistributed(
            0,
            FEE_AMOUNT * 4000 / 10000, // 40%
            FEE_AMOUNT * 3000 / 10000, // 30%
            FEE_AMOUNT * 2000 / 10000, // 20%
            FEE_AMOUNT * 1000 / 10000  // 10%
        );
        
        // Distribute fees
        distributor.distributeFees();
        
        // Verify distribution
        assertEq(
            andeToken.balanceOf(sequencerRegistry),
            initialSequencerBalance + FEE_AMOUNT * 4000 / 10000
        );
        assertEq(
            andeToken.balanceOf(stakingContract),
            initialStakingBalance + FEE_AMOUNT * 3000 / 10000
        );
        assertEq(
            andeToken.balanceOf(protocolTreasury),
            initialProtocolBalance + FEE_AMOUNT * 2000 / 10000
        );
        assertEq(
            andeToken.balanceOf(communityTreasury),
            initialCommunityBalance + FEE_AMOUNT * 1000 / 10000
        );
    }

    function testMultipleCollectAndDistribute() public {
        vm.startPrank(owner);
        
        // Approve enough tokens for 3 collections
        andeToken.approve(address(distributor), FEE_AMOUNT * 3);
        
        // Collect fees multiple times
        for (uint i = 0; i < 3; i++) {
            distributor.collectFees(FEE_AMOUNT);
        }
        
        vm.stopPrank();
        
        // Check total fees collected
        assertEq(distributor.totalFeesCollected(), FEE_AMOUNT * 3);
        
        // Distribute all fees
        distributor.distributeFees();
        
        // Verify total distribution
        uint256 totalDistributed = FEE_AMOUNT * 3;
        assertEq(
            andeToken.balanceOf(sequencerRegistry),
            totalDistributed * 4000 / 10000
        );
        assertEq(
            andeToken.balanceOf(stakingContract),
            totalDistributed * 3000 / 10000
        );
        assertEq(
            andeToken.balanceOf(protocolTreasury),
            totalDistributed * 2000 / 10000
        );
        assertEq(
            andeToken.balanceOf(communityTreasury),
            totalDistributed * 1000 / 10000
        );
    }

    function testEndEpoch() public {
        // Collect some fees
        vm.startPrank(owner);
        andeToken.approve(address(distributor), FEE_AMOUNT);
        distributor.collectFees(FEE_AMOUNT);
        
        // Warp time forward by 7 days (EPOCH_DURATION)
        vm.warp(block.timestamp + 7 days);
        
        // Expect event
        vm.expectEmit(true, false, false, true);
        emit EpochEnded(0, FEE_AMOUNT);
        
        // End epoch
        distributor.endEpoch();
        
        vm.stopPrank();
        
        // Check new epoch started
        assertEq(distributor.currentEpoch(), 1);
        
        // Check previous epoch stats
        AndeFeeDistributor.EpochStats memory stats = distributor.getEpochStats(0);
        assertEq(stats.totalFeesCollected, FEE_AMOUNT);
        assertGt(stats.endTime, 0);
    }

    function testEndEpochUnauthorized() public {
        vm.expectRevert();
        distributor.endEpoch();
    }

    function testUpdateSequencerRegistry() public {
        address newRegistry = address(0x6);
        
        vm.startPrank(owner);
        
        distributor.updateSequencerRegistry(newRegistry);
        
        vm.stopPrank();
        
        assertEq(distributor.sequencerRegistry(), newRegistry);
    }

    function testUpdateSequencerRegistryUnauthorized() public {
        vm.expectRevert();
        distributor.updateSequencerRegistry(address(0x6));
    }

    function testUpdateStakingContract() public {
        address newStaking = address(0x7);
        
        vm.startPrank(owner);
        
        distributor.updateStakingContract(newStaking);
        
        vm.stopPrank();
        
        assertEq(distributor.stakingContract(), newStaking);
    }

    function testUpdateProtocolTreasury() public {
        address newTreasury = address(0x8);
        
        vm.startPrank(owner);
        
        distributor.updateProtocolTreasury(newTreasury);
        
        vm.stopPrank();
        
        assertEq(distributor.protocolTreasury(), newTreasury);
    }

    function testUpdateCommunityTreasury() public {
        address newTreasury = address(0x9);
        
        vm.startPrank(owner);
        
        distributor.updateCommunityTreasury(newTreasury);
        
        vm.stopPrank();
        
        assertEq(distributor.communityTreasury(), newTreasury);
    }

    function testGetCurrentEpochStats() public {
        vm.startPrank(owner);
        andeToken.approve(address(distributor), FEE_AMOUNT);
        distributor.collectFees(FEE_AMOUNT);
        vm.stopPrank();
        
        AndeFeeDistributor.EpochStats memory stats = distributor.getCurrentEpochStats();
        assertEq(stats.totalFeesCollected, FEE_AMOUNT);
        assertEq(stats.startTime, block.timestamp);
    }

    function testGetEpochStats() public {
        // Collect fees and end epoch
        vm.startPrank(owner);
        andeToken.approve(address(distributor), FEE_AMOUNT);
        distributor.collectFees(FEE_AMOUNT);
        
        // Warp time forward by 7 days
        vm.warp(block.timestamp + 7 days);
        
        distributor.endEpoch();
        vm.stopPrank();
        
        // Get epoch 0 stats
        AndeFeeDistributor.EpochStats memory stats = distributor.getEpochStats(0);
        assertEq(stats.totalFeesCollected, FEE_AMOUNT);
        assertGt(stats.endTime, 0);
    }

    function testPauseAndUnpause() public {
        vm.startPrank(owner);
        
        // Grant pauser role
        distributor.grantRole(distributor.PAUSER_ROLE(), owner);
        
        // Pause
        distributor.pause();
        assertTrue(distributor.paused());
        
        // Try to collect fees while paused
        andeToken.approve(address(distributor), FEE_AMOUNT);
        vm.expectRevert();
        distributor.collectFees(FEE_AMOUNT);
        
        // Unpause
        distributor.unpause();
        assertFalse(distributor.paused());
        
        // Should work now (approval still valid)
        distributor.collectFees(FEE_AMOUNT);
        
        vm.stopPrank();
    }

    function testFeeCollectorRole() public {
        address collector = address(0xa);
        
        vm.startPrank(owner);
        
        // Grant fee collector role
        distributor.grantRole(distributor.FEE_COLLECTOR_ROLE(), collector);
        
        // Transfer some tokens to collector for testing
        andeToken.transfer(collector, FEE_AMOUNT);
        
        vm.stopPrank();
        
        // Collector should be able to collect fees
        vm.startPrank(collector);
        andeToken.approve(address(distributor), FEE_AMOUNT);
        distributor.collectFees(FEE_AMOUNT);
        vm.stopPrank();
        
        assertEq(distributor.totalFeesCollected(), FEE_AMOUNT);
    }

    function testMultipleEpochs() public {
        vm.startPrank(owner);
        
        // Approve enough for all epochs
        andeToken.approve(address(distributor), FEE_AMOUNT * 6);
        
        // Epoch 0
        distributor.collectFees(FEE_AMOUNT);
        vm.warp(block.timestamp + 7 days);
        distributor.endEpoch();
        
        // Epoch 1
        distributor.collectFees(FEE_AMOUNT * 2);
        vm.warp(block.timestamp + 7 days);
        distributor.endEpoch();
        
        // Epoch 2
        distributor.collectFees(FEE_AMOUNT * 3);
        
        vm.stopPrank();
        
        // Check current epoch
        assertEq(distributor.currentEpoch(), 2);
        
        // Check epoch stats
        AndeFeeDistributor.EpochStats memory stats0 = distributor.getEpochStats(0);
        assertEq(stats0.totalFeesCollected, FEE_AMOUNT);
        
        AndeFeeDistributor.EpochStats memory stats1 = distributor.getEpochStats(1);
        assertEq(stats1.totalFeesCollected, FEE_AMOUNT * 2);
        
        AndeFeeDistributor.EpochStats memory stats2 = distributor.getCurrentEpochStats();
        assertEq(stats2.totalFeesCollected, FEE_AMOUNT * 3);
    }
}
