// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AndeConsensus} from "../../src/consensus/AndeConsensus.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AndeConsensusTest is Test {
    AndeConsensus public consensus;
    
    address public admin = address(1);
    address public stakingContract = address(2);
    address public sequencerRegistry = address(3);
    address public genesisValidator = address(100);
    address public validator2 = address(200);
    address public validator3 = address(300);
    
    bytes32 public constant GENESIS_PEER_ID = bytes32(uint256(1));
    string public constant GENESIS_RPC = "https://genesis.ande.network";
    
    // Events from AndeConsensus
    event ValidatorSetUpdated(
        uint256 indexed epoch,
        address[] validators,
        uint256[] powers,
        uint256 totalPower
    );
    
    event BlockProposed(
        uint256 indexed blockNumber,
        bytes32 indexed blockHash,
        address indexed producer,
        uint256 timestamp
    );
    
    event ProposerSelected(
        uint256 indexed blockNumber,
        address indexed proposer,
        int256 priority
    );
    
    event ValidatorSlashed(
        address indexed validator,
        uint256 amount,
        string reason,
        uint256 timestamp
    );
    
    event ValidatorJailed(
        address indexed validator,
        string reason,
        uint256 timestamp
    );
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy implementation
        AndeConsensus impl = new AndeConsensus();
        
        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            AndeConsensus.initialize.selector,
            admin,
            stakingContract,
            sequencerRegistry,
            genesisValidator,
            GENESIS_PEER_ID,
            GENESIS_RPC
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        consensus = AndeConsensus(address(proxy));
        
        vm.stopPrank();
    }
    
    // ============================================
    // INITIALIZATION TESTS
    // ============================================
    
    function testInitialization() public {
        assertEq(consensus.currentEpoch(), 1);
        assertEq(consensus.totalVotingPower(), 100);
        assertEq(consensus.getCurrentProposer(), genesisValidator);
        assertEq(consensus.getActiveValidatorsCount(), 1);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(genesisValidator);
        assertEq(info.validator, genesisValidator);
        assertEq(info.power, 100);
        assertTrue(info.active);
        assertTrue(info.isPermanent);
    }
    
    function testCannotReinitialize() public {
        vm.expectRevert();
        consensus.initialize(
            admin,
            stakingContract,
            sequencerRegistry,
            genesisValidator,
            GENESIS_PEER_ID,
            GENESIS_RPC
        );
    }
    
    // ============================================
    // VALIDATOR REGISTRATION TESTS
    // ============================================
    
    function testRegisterValidator() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        assertEq(consensus.getActiveValidatorsCount(), 2);
        assertEq(consensus.totalVotingPower(), 200);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertEq(info.validator, validator2);
        assertEq(info.power, 100);
        assertTrue(info.active);
        assertFalse(info.isPermanent);
        
        vm.stopPrank();
    }
    
    function testRegisterMultipleValidators() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        consensus.registerValidator(
            validator3,
            bytes32(uint256(3)),
            "https://validator3.ande.network",
            100000 * 1e18,
            200
        );
        
        assertEq(consensus.getActiveValidatorsCount(), 3);
        assertEq(consensus.totalVotingPower(), 400);
        
        vm.stopPrank();
    }
    
    function testCannotRegisterWithoutRole() public {
        vm.startPrank(address(999));
        
        vm.expectRevert();
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        vm.stopPrank();
    }
    
    function testCannotRegisterWithZeroPower() public {
        vm.startPrank(admin);
        
        vm.expectRevert(AndeConsensus.InvalidVotingPower.selector);
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            0
        );
        
        vm.stopPrank();
    }
    
    // ============================================
    // PROPOSER SELECTION TESTS (Critical!)
    // ============================================
    
    function testProposerSelectionSingleValidator() public {
        // With 1 validator, should always be the proposer
        address proposer = consensus.getCurrentProposer();
        assertEq(proposer, genesisValidator);
        
        // Query block producer
        address producer = consensus.getBlockProducer(1);
        assertEq(producer, genesisValidator);
    }
    
    function testProposerSelectionTwoValidatorsEqual() public {
        vm.startPrank(admin);
        
        // Register second validator with equal voting power
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        vm.stopPrank();
        
        // Simulate block proposals to see rotation
        // Genesis: priority = 0, Validator2: priority = 0
        // Round 1: Both increment by 100 -> Genesis: 100, Val2: 100
        //          Genesis selected (first in case of tie)
        //          Genesis: 100 - 200 = -100
        // Round 2: Genesis: -100 + 100 = 0, Val2: 100 + 100 = 200
        //          Val2 selected
        //          Val2: 200 - 200 = 0
        // Pattern should alternate
        
        address firstProposer = consensus.getCurrentProposer();
        console.log("First proposer:", firstProposer);
        
        // We can't easily test rotation without actually proposing blocks
        // which requires valid signatures. This is tested in integration tests.
    }
    
    function testProposerSelectionWeightedPower() public {
        vm.startPrank(admin);
        
        // Register validator2 with 3x voting power of genesis
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            150000 * 1e18,
            300
        );
        
        vm.stopPrank();
        
        // Total VP = 400
        // Genesis: 100 (25%), Validator2: 300 (75%)
        // Over 400 blocks, genesis should get ~100, validator2 should get ~300
        
        assertEq(consensus.totalVotingPower(), 400);
    }
    
    // ============================================
    // VALIDATOR POWER UPDATE TESTS
    // ============================================
    
    function testUpdateValidatorPower() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        // Update power
        consensus.updateValidatorPower(validator2, 200);
        
        assertEq(consensus.totalVotingPower(), 300);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertEq(info.power, 200);
        
        vm.stopPrank();
    }
    
    function testCannotUpdateInactiveValidator() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        // Deactivate
        consensus.deactivateValidator(validator2);
        
        // Try to update
        vm.expectRevert(abi.encodeWithSelector(AndeConsensus.ValidatorNotActive.selector, validator2));
        consensus.updateValidatorPower(validator2, 200);
        
        vm.stopPrank();
    }
    
    // ============================================
    // VALIDATOR DEACTIVATION TESTS
    // ============================================
    
    function testDeactivateValidator() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        assertEq(consensus.getActiveValidatorsCount(), 2);
        
        // Deactivate
        consensus.deactivateValidator(validator2);
        
        assertEq(consensus.getActiveValidatorsCount(), 1);
        assertEq(consensus.totalVotingPower(), 100);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertFalse(info.active);
        
        vm.stopPrank();
    }
    
    function testCannotDeactivatePermanentValidator() public {
        vm.startPrank(admin);
        
        vm.expectRevert(abi.encodeWithSelector(AndeConsensus.ValidatorNotActive.selector, genesisValidator));
        consensus.deactivateValidator(genesisValidator);
        
        vm.stopPrank();
    }
    
    // ============================================
    // SLASHING TESTS
    // ============================================
    
    function testSlashDowntime() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            100000 * 1e18,
            100
        );
        
        vm.stopPrank();
        
        // Simulate downtime by setting low uptime
        // (In real scenario, this would be tracked by the system)
        
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit ValidatorSlashed(validator2, 5000 * 1e18, "Downtime", block.timestamp);
        
        vm.expectEmit(true, true, true, true);
        emit ValidatorJailed(validator2, "Downtime", block.timestamp);
        
        consensus.slashDowntime(validator2);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertTrue(info.jailed);
        assertFalse(info.active);
        assertEq(info.stake, 95000 * 1e18); // 100k - 5% = 95k
        
        vm.stopPrank();
    }
    
    function testUnjailValidator() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            100000 * 1e18,
            100
        );
        
        // Slash for downtime (jails validator)
        consensus.slashDowntime(validator2);
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertTrue(info.jailed);
        
        // Unjail
        consensus.unjailValidator(validator2);
        
        info = consensus.getValidatorInfo(validator2);
        assertFalse(info.jailed);
        assertTrue(info.active);
        
        vm.stopPrank();
    }
    
    // ============================================
    // EPOCH MANAGEMENT TESTS
    // ============================================
    
    function testEpochInfo() public {
        AndeConsensus.EpochInfo memory epoch = consensus.getEpochInfo(1);
        
        assertEq(epoch.epochNumber, 1);
        assertEq(epoch.startBlock, 0);
        assertEq(epoch.validators.length, 1);
        assertEq(epoch.validators[0], genesisValidator);
        assertEq(epoch.totalVotingPower, 100);
    }
    
    function testCannotAdvanceEpochEarly() public {
        vm.startPrank(admin);
        
        vm.expectRevert(AndeConsensus.EpochNotEnded.selector);
        consensus.advanceEpoch();
        
        vm.stopPrank();
    }
    
    // ============================================
    // PAUSE TESTS
    // ============================================
    
    function testPauseUnpause() public {
        vm.startPrank(admin);
        
        consensus.pause();
        
        // Cannot register when paused
        vm.expectRevert();
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        consensus.unpause();
        
        // Can register after unpause
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        assertEq(consensus.getActiveValidatorsCount(), 2);
        
        vm.stopPrank();
    }
    
    // ============================================
    // VIEW FUNCTION TESTS
    // ============================================
    
    function testGetActiveValidators() public {
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        consensus.registerValidator(
            validator3,
            bytes32(uint256(3)),
            "https://validator3.ande.network",
            100000 * 1e18,
            200
        );
        
        address[] memory validators = consensus.getActiveValidators();
        assertEq(validators.length, 3);
        assertEq(validators[0], genesisValidator);
        assertEq(validators[1], validator2);
        assertEq(validators[2], validator3);
        
        vm.stopPrank();
    }
    
    function testIsValidator() public {
        assertTrue(consensus.isValidator(genesisValidator));
        assertFalse(consensus.isValidator(validator2));
        
        vm.startPrank(admin);
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        assertTrue(consensus.isValidator(validator2));
        
        vm.stopPrank();
    }
    
    // ============================================
    // INTEGRATION SCENARIO TESTS
    // ============================================
    
    function testMultiValidatorScenario() public {
        vm.startPrank(admin);
        
        // Register 3 validators with different powers
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            50000 * 1e18,
            100
        );
        
        consensus.registerValidator(
            validator3,
            bytes32(uint256(3)),
            "https://validator3.ande.network",
            100000 * 1e18,
            200
        );
        
        // Check state
        assertEq(consensus.getActiveValidatorsCount(), 3);
        assertEq(consensus.totalVotingPower(), 400);
        
        // Deactivate one
        consensus.deactivateValidator(validator2);
        
        assertEq(consensus.getActiveValidatorsCount(), 2);
        assertEq(consensus.totalVotingPower(), 300);
        
        // Update power of remaining
        consensus.updateValidatorPower(validator3, 300);
        
        assertEq(consensus.totalVotingPower(), 400);
        
        vm.stopPrank();
    }
}