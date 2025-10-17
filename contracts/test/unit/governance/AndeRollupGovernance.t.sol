// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AndeRollupGovernance, IAndeSequencerRegistry} from "../../../src/governance/AndeRollupGovernance.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockSequencerRegistry is IAndeSequencerRegistry {
    mapping(address => bool) public sequencers;
    mapping(address => uint256) public stakes;
    
    function addSequencer(address sequencer, uint256 stake) external {
        sequencers[sequencer] = true;
        stakes[sequencer] = stake;
    }
    
    function removeSequencer(address sequencer) external {
        sequencers[sequencer] = false;
        stakes[sequencer] = 0;
    }
    
    function updateSequencerStake(address sequencer, uint256 newStake) external {
        stakes[sequencer] = newStake;
    }
    
    function isSequencer(address sequencer) external view returns (bool) {
        return sequencers[sequencer];
    }
}

contract AndeRollupGovernanceTest is Test {
    AndeRollupGovernance public rollupGov;
    MockSequencerRegistry public sequencerRegistry;
    
    address public governor = address(0x1);
    address public emergency = address(0x2);
    address public pauser = address(0x3);
    address public user = address(0x4);
    address public sequencer1 = address(0x5);
    address public sequencer2 = address(0x6);
    
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    function setUp() public {
        sequencerRegistry = new MockSequencerRegistry();
        
        AndeRollupGovernance implementation = new AndeRollupGovernance();
        bytes memory initData = abi.encodeWithSelector(
            AndeRollupGovernance.initialize.selector,
            address(sequencerRegistry),
            governor
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        rollupGov = AndeRollupGovernance(address(proxy));
        
        vm.startPrank(governor);
        rollupGov.grantRole(EMERGENCY_ROLE, emergency);
        rollupGov.grantRole(PAUSER_ROLE, pauser);
        vm.stopPrank();
    }
    
    function testInitialization() public view {
        assertEq(address(rollupGov.sequencerRegistry()), address(sequencerRegistry));
        assertEq(rollupGov.baseFeePerGas(), 1 gwei);
        assertEq(rollupGov.priorityFeePerGas(), 1 gwei);
        assertEq(rollupGov.sequencerCutBps(), 4000);
        assertEq(rollupGov.celestiaDAFee(), 0.01 ether);
        assertFalse(rollupGov.paused());
        assertTrue(rollupGov.hasRole(GOVERNOR_ROLE, governor));
        assertTrue(rollupGov.hasRole(rollupGov.DEFAULT_ADMIN_ROLE(), governor));
    }
    
    function testUpdateBaseFee() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.BaseFeeUpdated(1 gwei, 10 gwei);
        rollupGov.updateBaseFee(10 gwei);
        
        assertEq(rollupGov.baseFeePerGas(), 10 gwei);
    }
    
    function testUpdateBaseFeeRevertsIfTooHigh() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.FeeExceedsMaximum.selector);
        rollupGov.updateBaseFee(1001 gwei);
    }
    
    function testUpdateBaseFeeRequiresGovernorRole() public {
        vm.prank(user);
        vm.expectRevert();
        rollupGov.updateBaseFee(10 gwei);
    }
    
    function testUpdateBaseFeeRevertsWhenPaused() public {
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updateBaseFee(10 gwei);
    }
    
    function testUpdatePriorityFee() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.PriorityFeeUpdated(1 gwei, 5 gwei);
        rollupGov.updatePriorityFee(5 gwei);
        
        assertEq(rollupGov.priorityFeePerGas(), 5 gwei);
    }
    
    function testUpdatePriorityFeeRevertsIfTooHigh() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.FeeExceedsMaximum.selector);
        rollupGov.updatePriorityFee(101 gwei);
    }
    
    function testUpdateSequencerCut() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.SequencerCutUpdated(4000, 3000);
        rollupGov.updateSequencerCut(3000);
        
        assertEq(rollupGov.sequencerCutBps(), 3000);
    }
    
    function testUpdateSequencerCutRevertsIfTooHigh() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.InvalidBasisPoints.selector);
        rollupGov.updateSequencerCut(5001);
    }
    
    function testAddSequencer() public {
        uint256 stake = 100_000 ether;
        
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.SequencerAdded(sequencer1, stake);
        rollupGov.addSequencer(sequencer1, stake);
        
        assertTrue(sequencerRegistry.isSequencer(sequencer1));
        assertEq(sequencerRegistry.stakes(sequencer1), stake);
    }
    
    function testAddSequencerRevertsIfZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.ZeroAddress.selector);
        rollupGov.addSequencer(address(0), 100_000 ether);
    }
    
    function testAddSequencerRevertsIfStakeTooLow() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.InvalidSequencerStake.selector);
        rollupGov.addSequencer(sequencer1, 99_999 ether);
    }
    
    function testAddSequencerRevertsWhenPaused() public {
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
    }
    
    function testRemoveSequencer() public {
        vm.startPrank(governor);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.SequencerRemoved(sequencer1);
        rollupGov.removeSequencer(sequencer1);
        vm.stopPrank();
        
        assertFalse(sequencerRegistry.isSequencer(sequencer1));
    }
    
    function testRemoveSequencerWorksEvenWhenPaused() public {
        vm.startPrank(governor);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        vm.stopPrank();
        
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.prank(governor);
        rollupGov.removeSequencer(sequencer1);
        
        assertFalse(sequencerRegistry.isSequencer(sequencer1));
    }
    
    function testUpdateSequencerStake() public {
        vm.startPrank(governor);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        
        uint256 newStake = 200_000 ether;
        rollupGov.updateSequencerStake(sequencer1, newStake);
        vm.stopPrank();
        
        assertEq(sequencerRegistry.stakes(sequencer1), newStake);
    }
    
    function testUpdateSequencerStakeRevertsIfTooLow() public {
        vm.startPrank(governor);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        
        vm.expectRevert(AndeRollupGovernance.InvalidSequencerStake.selector);
        rollupGov.updateSequencerStake(sequencer1, 50_000 ether);
        vm.stopPrank();
    }
    
    function testUpdateCelestiaDAFee() public {
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.CelestiaDAFeeUpdated(0.01 ether, 0.02 ether);
        rollupGov.updateCelestiaDAFee(0.02 ether);
        
        assertEq(rollupGov.celestiaDAFee(), 0.02 ether);
    }
    
    function testUpdateCelestiaNamespace() public {
        bytes29 newNamespace = bytes29(keccak256("test-namespace"));
        
        vm.prank(governor);
        rollupGov.updateCelestiaNamespace(newNamespace);
        
        assertEq(rollupGov.celestiaNamespace(), newNamespace);
    }
    
    function testUpdateSequencerRegistry() public {
        MockSequencerRegistry newRegistry = new MockSequencerRegistry();
        
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.SequencerRegistryUpdated(
            address(sequencerRegistry),
            address(newRegistry)
        );
        rollupGov.updateSequencerRegistry(address(newRegistry));
        
        assertEq(address(rollupGov.sequencerRegistry()), address(newRegistry));
    }
    
    function testUpdateSequencerRegistryRevertsIfZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(AndeRollupGovernance.ZeroAddress.selector);
        rollupGov.updateSequencerRegistry(address(0));
    }
    
    function testEmergencyPause() public {
        vm.prank(emergency);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.EmergencyPaused(emergency);
        rollupGov.emergencyPause();
        
        assertTrue(rollupGov.paused());
    }
    
    function testEmergencyPauseRequiresEmergencyRole() public {
        vm.prank(user);
        vm.expectRevert();
        rollupGov.emergencyPause();
    }
    
    function testEmergencyPauseRevertsIfAlreadyPaused() public {
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.prank(emergency);
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.emergencyPause();
    }
    
    function testEmergencyUnpause() public {
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.prank(emergency);
        vm.expectEmit(true, true, true, true);
        emit AndeRollupGovernance.EmergencyUnpaused(emergency);
        rollupGov.emergencyUnpause();
        
        assertFalse(rollupGov.paused());
    }
    
    function testEmergencyUnpauseRevertsIfNotPaused() public {
        vm.prank(emergency);
        vm.expectRevert(AndeRollupGovernance.RollupNotPaused.selector);
        rollupGov.emergencyUnpause();
    }
    
    function testCalculateTotalFee() public {
        vm.prank(governor);
        rollupGov.updateBaseFee(10 gwei);
        
        vm.prank(governor);
        rollupGov.updatePriorityFee(2 gwei);
        
        uint256 gasUsed = 100_000;
        uint256 expectedFee = (10 gwei + 2 gwei) * gasUsed;
        
        assertEq(rollupGov.calculateTotalFee(gasUsed), expectedFee);
    }
    
    function testCalculateSequencerCut() public {
        vm.prank(governor);
        rollupGov.updateSequencerCut(3000);
        
        uint256 totalFee = 1 ether;
        uint256 expectedCut = (totalFee * 3000) / 10000;
        
        assertEq(rollupGov.calculateSequencerCut(totalFee), expectedCut);
    }
    
    function testGetRollupParameters() public {
        (
            uint256 baseFee,
            uint256 priorityFee,
            uint256 sequencerCut,
            uint256 celestiaFee,
            bool isPaused
        ) = rollupGov.getRollupParameters();
        
        assertEq(baseFee, 1 gwei);
        assertEq(priorityFee, 1 gwei);
        assertEq(sequencerCut, 4000);
        assertEq(celestiaFee, 0.01 ether);
        assertFalse(isPaused);
    }
    
    function testMultipleSequencerManagement() public {
        vm.startPrank(governor);
        
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        rollupGov.addSequencer(sequencer2, 150_000 ether);
        
        assertTrue(sequencerRegistry.isSequencer(sequencer1));
        assertTrue(sequencerRegistry.isSequencer(sequencer2));
        assertEq(sequencerRegistry.stakes(sequencer1), 100_000 ether);
        assertEq(sequencerRegistry.stakes(sequencer2), 150_000 ether);
        
        rollupGov.updateSequencerStake(sequencer1, 200_000 ether);
        assertEq(sequencerRegistry.stakes(sequencer1), 200_000 ether);
        
        rollupGov.removeSequencer(sequencer1);
        assertFalse(sequencerRegistry.isSequencer(sequencer1));
        assertTrue(sequencerRegistry.isSequencer(sequencer2));
        
        vm.stopPrank();
    }
    
    function testFeeUpdatesAcrossMultipleOperations() public {
        vm.startPrank(governor);
        
        rollupGov.updateBaseFee(50 gwei);
        rollupGov.updatePriorityFee(10 gwei);
        rollupGov.updateSequencerCut(2500);
        
        assertEq(rollupGov.baseFeePerGas(), 50 gwei);
        assertEq(rollupGov.priorityFeePerGas(), 10 gwei);
        assertEq(rollupGov.sequencerCutBps(), 2500);
        
        uint256 gasUsed = 50_000;
        uint256 totalFee = rollupGov.calculateTotalFee(gasUsed);
        uint256 sequencerRevenue = rollupGov.calculateSequencerCut(totalFee);
        
        assertEq(totalFee, (50 gwei + 10 gwei) * gasUsed);
        assertEq(sequencerRevenue, (totalFee * 2500) / 10000);
        
        vm.stopPrank();
    }
    
    function testPausePreventsMostOperations() public {
        vm.prank(emergency);
        rollupGov.emergencyPause();
        
        vm.startPrank(governor);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updateBaseFee(10 gwei);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updatePriorityFee(2 gwei);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updateSequencerCut(3000);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.addSequencer(sequencer1, 100_000 ether);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updateCelestiaDAFee(0.05 ether);
        
        vm.expectRevert(AndeRollupGovernance.RollupPaused.selector);
        rollupGov.updateCelestiaNamespace(bytes29(0));
        
        rollupGov.removeSequencer(sequencer1);
        
        rollupGov.updateSequencerRegistry(address(new MockSequencerRegistry()));
        
        vm.stopPrank();
    }
}
