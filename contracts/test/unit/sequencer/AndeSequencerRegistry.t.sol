// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeSequencerRegistry} from "../../../src/sequencer/AndeSequencerRegistry.sol";
import {ANDETokenDuality as ANDEToken} from "../../../src/ANDETokenDuality.sol";
import {NativeTransferPrecompileMock} from "../../../src/mocks/NativeTransferPrecompileMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ANDETokenTestHelper} from "../../helpers/ANDETokenTestHelper.sol";

contract AndeSequencerRegistryTest is Test, ANDETokenTestHelper {
    AndeSequencerRegistry public registry;
    ANDEToken public andeToken;
    NativeTransferPrecompileMock public precompile;
    
    address public owner = address(0x1);
    address public foundation = address(0x2);
    address public sequencer1 = address(0x3);
    address public sequencer2 = address(0x4);
    address public unauthorizedUser = address(0x5);
    
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18; // 1B ANDE
    
    event SequencerRegistered(
        address indexed sequencer,
        uint256 stakedAmount,
        string endpoint
    );
    event BlockProduced(
        address indexed sequencer,
        uint256 blockNumber,
        uint256 epoch
    );
    event PhaseTransitioned(
        AndeSequencerRegistry.Phase indexed oldPhase,
        AndeSequencerRegistry.Phase indexed newPhase
    );

    function setUp() public {
        (andeToken, precompile) = deployANDETokenWithSupply(owner, owner, TOTAL_SUPPLY);
        
        vm.startPrank(owner);
        
        AndeSequencerRegistry registryImpl = new AndeSequencerRegistry();
        bytes memory registryInitData = abi.encodeWithSelector(AndeSequencerRegistry.initialize.selector, owner, foundation);
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryImpl), registryInitData);
        registry = AndeSequencerRegistry(address(registryProxy));
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(uint(registry.currentPhase()), uint(AndeSequencerRegistry.Phase.GENESIS));
        assertEq(registry.getActiveSequencersCount(), 1);
    }

    function testGenesisSequencerRegistered() public {
        address[] memory activeSequencers = registry.getActiveSequencers();
        assertEq(activeSequencers.length, 1);
        assertEq(activeSequencers[0], foundation);
    }

    function testGetCurrentLeader() public {
        address leader = registry.getCurrentLeader();
        assertEq(leader, foundation);
    }

    function testGetSequencerInfo() public {
        AndeSequencerRegistry.SequencerInfo memory info = registry.getSequencerInfo(foundation);
        assertEq(info.sequencer, foundation);
        assertTrue(info.isActive);
        assertTrue(info.isPermanent);
    }

    function testRecordBlockProduced() public {
        vm.startPrank(owner);
        
        // Record block produced by genesis sequencer
        registry.recordBlockProduced(foundation);
        
        vm.stopPrank();
        
        // Check that block was recorded
        AndeSequencerRegistry.SequencerInfo memory info = registry.getSequencerInfo(foundation);
        assertEq(info.totalBlocksProduced, 1);
    }

    function testRecordBlockProducedUnauthorized() public {
        vm.expectRevert();
        registry.recordBlockProduced(foundation);
    }

    function testTransitionPhase() public {
        vm.startPrank(owner);
        
        // Warp time forward to enable phase transition
        vm.warp(block.timestamp + 180 days);
        
        uint256 expectedTimestamp = block.timestamp;
        
        // Transition to DUAL phase
        registry.transitionPhase();
        
        vm.stopPrank();
        
        assertEq(uint(registry.currentPhase()), uint(AndeSequencerRegistry.Phase.DUAL));
    }

    function testTransitionPhaseUnauthorized() public {
        vm.expectRevert();
        registry.transitionPhase();
    }

    function testMultiplePhaseTransitions() public {
        vm.startPrank(owner);
        
        // Transition through all phases with proper time delays
        // GENESIS -> DUAL (after 180 days)
        vm.warp(block.timestamp + 180 days);
        registry.transitionPhase();
        assertEq(uint(registry.currentPhase()), uint(AndeSequencerRegistry.Phase.DUAL));
        
        // DUAL -> MULTI (after another 180 days)
        vm.warp(block.timestamp + 180 days);
        registry.transitionPhase();
        assertEq(uint(registry.currentPhase()), uint(AndeSequencerRegistry.Phase.MULTI));
        
        // MULTI -> DECENTRALIZED (after another 365 days)
        vm.warp(block.timestamp + 365 days);
        registry.transitionPhase();
        assertEq(uint(registry.currentPhase()), uint(AndeSequencerRegistry.Phase.DECENTRALIZED));
        
        vm.stopPrank();
    }

    function testStartNewEpoch() public {
        vm.startPrank(owner);
        
        // Record some blocks first
        registry.recordBlockProduced(foundation);
        registry.recordBlockProduced(foundation);
        
        // Warp time forward by 90 days (EPOCH_DURATION)
        vm.warp(block.timestamp + 90 days);
        
        // Start new epoch
        registry.startNewEpoch();
        
        vm.stopPrank();
        
        // Epoch should have advanced
        assertEq(registry.currentEpoch(), 2);
    }

    function testStartNewEpochUnauthorized() public {
        vm.expectRevert();
        registry.startNewEpoch();
    }

    function testGetActiveSequencers() public {
        address[] memory activeSequencers = registry.getActiveSequencers();
        assertEq(activeSequencers.length, 1);
        assertEq(activeSequencers[0], foundation);
    }

    function testGetActiveSequencersCount() public {
        assertEq(registry.getActiveSequencersCount(), 1);
    }

    function testPauseAndUnpause() public {
        vm.startPrank(owner);
        
        // Grant pauser role
        registry.grantRole(registry.PAUSER_ROLE(), owner);
        
        // Pause
        registry.pause();
        assertTrue(registry.paused());
        
        // Try to record block while paused
        vm.expectRevert();
        registry.recordBlockProduced(foundation);
        
        // Unpause
        registry.unpause();
        assertFalse(registry.paused());
        
        // Should work now
        registry.recordBlockProduced(foundation);
        
        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.expectRevert();
        registry.pause();
    }

    function testSequencerManagerRole() public {
        address manager = address(0x6);
        
        vm.startPrank(owner);
        
        // Grant sequencer manager role
        registry.grantRole(registry.SEQUENCER_MANAGER_ROLE(), manager);
        
        vm.stopPrank();
        
        // Manager should be able to record blocks
        vm.prank(manager);
        registry.recordBlockProduced(foundation);
        
        AndeSequencerRegistry.SequencerInfo memory info = registry.getSequencerInfo(foundation);
        assertEq(info.totalBlocksProduced, 1);
    }

    function testMultipleBlocksProduced() public {
        vm.startPrank(owner);
        
        // Record multiple blocks
        for (uint i = 0; i < 10; i++) {
            registry.recordBlockProduced(foundation);
        }
        
        vm.stopPrank();
        
        // Check total blocks produced
        AndeSequencerRegistry.SequencerInfo memory info = registry.getSequencerInfo(foundation);
        assertEq(info.totalBlocksProduced, 10);
    }

    function testEpochProgression() public {
        vm.startPrank(owner);
        
        // Initial epoch
        assertEq(registry.currentEpoch(), 1);
        
        // Warp time and start new epoch
        uint256 firstWarp = block.timestamp + 90 days;
        vm.warp(firstWarp);
        registry.startNewEpoch();
        assertEq(registry.currentEpoch(), 2);
        
        // Warp time again and start another epoch
        // Need to warp 90 more days from current time
        vm.warp(firstWarp + 90 days);
        registry.startNewEpoch();
        assertEq(registry.currentEpoch(), 3);
        
        vm.stopPrank();
    }
}
