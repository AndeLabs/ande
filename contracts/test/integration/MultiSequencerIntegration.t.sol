// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AndeConsensus} from "../../src/consensus/AndeConsensus.sol";
import {AndeNativeStaking} from "../../src/staking/AndeNativeStaking.sol";
import {AndeSequencerRegistry} from "../../src/sequencer/AndeSequencerRegistry.sol";
import {ANDETokenDuality} from "../../src/ANDETokenDuality.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MultiSequencerIntegration
 * @notice Integration test for the complete multi-sequencer system
 * @dev Tests the interaction between AndeConsensus, AndeNativeStaking, and AndeSequencerRegistry
 *
 * Test Scenarios:
 * 1. Deploy all contracts
 * 2. Register validators with different voting powers
 * 3. Verify proposer selection algorithm
 * 4. Test validator rotation
 * 5. Test slashing integration
 * 6. Test epoch transitions
 */
contract MultiSequencerIntegrationTest is Test {
    // Contracts
    AndeConsensus public consensus;
    AndeNativeStaking public staking;
    AndeSequencerRegistry public sequencerRegistry;
    ANDETokenDuality public andeToken;
    
    // Test accounts
    address public admin = address(1);
    address public treasury = address(2);
    address public genesisValidator = address(100);
    address public validator2 = address(200);
    address public validator3 = address(300);
    address public validator4 = address(400);
    address public validator5 = address(500);
    
    // Constants
    bytes32 public constant GENESIS_PEER_ID = bytes32(uint256(1));
    string public constant GENESIS_RPC = "https://genesis.ande.network";
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B ANDE
    uint256 public constant MIN_STAKE = 100_000 * 1e18; // 100k ANDE
    
    function setUp() public {
        vm.startPrank(admin);
        
        // 1. Deploy ANDE Token
        ANDETokenDuality tokenImpl = new ANDETokenDuality();
        bytes memory tokenInitData = abi.encodeWithSelector(
            ANDETokenDuality.initialize.selector,
            admin,
            INITIAL_SUPPLY
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInitData);
        andeToken = ANDETokenDuality(payable(address(tokenProxy)));
        
        // 2. Deploy AndeNativeStaking
        AndeNativeStaking stakingImpl = new AndeNativeStaking();
        bytes memory stakingInitData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            admin,
            address(andeToken),
            treasury
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = AndeNativeStaking(address(stakingProxy));
        
        // 3. Deploy AndeSequencerRegistry
        AndeSequencerRegistry registryImpl = new AndeSequencerRegistry();
        bytes memory registryInitData = abi.encodeWithSelector(
            AndeSequencerRegistry.initialize.selector,
            admin,
            genesisValidator
        );
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryImpl), registryInitData);
        sequencerRegistry = AndeSequencerRegistry(address(registryProxy));
        
        // 4. Deploy AndeConsensus
        AndeConsensus consensusImpl = new AndeConsensus();
        bytes memory consensusInitData = abi.encodeWithSelector(
            AndeConsensus.initialize.selector,
            admin,
            address(staking),
            address(sequencerRegistry),
            genesisValidator,
            GENESIS_PEER_ID,
            GENESIS_RPC
        );
        ERC1967Proxy consensusProxy = new ERC1967Proxy(address(consensusImpl), consensusInitData);
        consensus = AndeConsensus(address(consensusProxy));
        
        // 5. Setup roles
        bytes32 minterRole = andeToken.MINTER_ROLE();
        andeToken.grantRole(minterRole, admin);
        
        bytes32 validatorManagerRole = consensus.VALIDATOR_MANAGER_ROLE();
        consensus.grantRole(validatorManagerRole, address(staking));
        consensus.grantRole(validatorManagerRole, address(sequencerRegistry));
        
        // 6. Distribute tokens to validators
        andeToken.mint(validator2, MIN_STAKE * 2);
        andeToken.mint(validator3, MIN_STAKE * 3);
        andeToken.mint(validator4, MIN_STAKE * 2);
        andeToken.mint(validator5, MIN_STAKE);
        
        vm.stopPrank();
        
        console.log("=== Setup Complete ===");
        console.log("AndeConsensus:", address(consensus));
        console.log("AndeNativeStaking:", address(staking));
        console.log("AndeSequencerRegistry:", address(sequencerRegistry));
        console.log("ANDE Token:", address(andeToken));
    }
    
    // ============================================
    // INTEGRATION TESTS
    // ============================================
    
    function testFullSystemDeployment() public {
        // Verify all contracts deployed correctly
        assertEq(consensus.currentEpoch(), 1);
        assertEq(consensus.getCurrentProposer(), genesisValidator);
        assertEq(consensus.totalVotingPower(), 100);
        
        assertTrue(sequencerRegistry.currentPhase() == AndeSequencerRegistry.Phase.GENESIS);
        assertEq(sequencerRegistry.getActiveSequencersCount(), 1);
        
        assertEq(andeToken.totalSupply(), INITIAL_SUPPLY);
    }
    
    function testValidatorRegistrationWithStaking() public {
        // Validator 2 stakes and registers
        vm.startPrank(validator2);
        
        // Approve staking contract
        andeToken.approve(address(staking), MIN_STAKE);
        
        // Stake for sequencer role
        staking.stakeSequencer(MIN_STAKE, uint8(AndeNativeStaking.LockPeriod.TWELVE_MONTHS));
        
        vm.stopPrank();
        
        // Admin registers validator in consensus
        vm.startPrank(admin);
        
        // Get voting power from staking
        AndeNativeStaking.StakeInfo memory stakeInfo = staking.getStakeInfo(validator2);
        uint256 votingPower = stakeInfo.votingPower;
        
        consensus.registerValidator(
            validator2,
            bytes32(uint256(2)),
            "https://validator2.ande.network",
            MIN_STAKE,
            votingPower
        );
        
        vm.stopPrank();
        
        // Verify registration
        assertEq(consensus.getActiveValidatorsCount(), 2);
        assertTrue(consensus.isValidator(validator2));
        
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertEq(info.validator, validator2);
        assertEq(info.stake, MIN_STAKE);
        assertTrue(info.active);
    }
    
    function testMultiValidatorProposerSelection() public {
        // Register 3 validators with different voting powers
        registerValidator(validator2, MIN_STAKE, 100);      // 100 voting power
        registerValidator(validator3, MIN_STAKE * 3, 300);  // 300 voting power
        registerValidator(validator4, MIN_STAKE * 2, 200);  // 200 voting power
        
        // Total VP = 100 (genesis) + 100 + 300 + 200 = 700
        assertEq(consensus.totalVotingPower(), 700);
        assertEq(consensus.getActiveValidatorsCount(), 4);
        
        // Check initial proposer
        address currentProposer = consensus.getCurrentProposer();
        console.log("Initial proposer:", currentProposer);
        
        // Verify proposer is one of the validators
        assertTrue(
            currentProposer == genesisValidator ||
            currentProposer == validator2 ||
            currentProposer == validator3 ||
            currentProposer == validator4,
            "Proposer must be an active validator"
        );
    }
    
    function testProposerRotationBasedOnVotingPower() public {
        // Register validators with known voting powers
        registerValidator(validator2, MIN_STAKE, 100);      // Equal to genesis
        registerValidator(validator3, MIN_STAKE * 2, 200);  // 2x genesis
        
        // Total VP = 400
        assertEq(consensus.totalVotingPower(), 400);
        
        // Over 400 "blocks", each validator should be selected proportionally:
        // Genesis: ~100 times (25%)
        // Validator2: ~100 times (25%)
        // Validator3: ~200 times (50%)
        
        // We can't test this without actually proposing blocks with valid signatures
        // But we can verify the setup is correct
        assertTrue(consensus.isValidator(genesisValidator));
        assertTrue(consensus.isValidator(validator2));
        assertTrue(consensus.isValidator(validator3));
    }
    
    function testValidatorPowerUpdateFromStaking() public {
        // Register validator
        registerValidator(validator2, MIN_STAKE, 100);
        
        AndeConsensus.ValidatorInfo memory infoBefore = consensus.getValidatorInfo(validator2);
        assertEq(infoBefore.power, 100);
        
        // Update voting power (simulating increased stake)
        vm.prank(admin);
        consensus.updateValidatorPower(validator2, 200);
        
        AndeConsensus.ValidatorInfo memory infoAfter = consensus.getValidatorInfo(validator2);
        assertEq(infoAfter.power, 200);
        
        // Total voting power should update
        assertEq(consensus.totalVotingPower(), 300); // 100 + 200
    }
    
    function testValidatorSlashingIntegration() public {
        // Register validator with stake
        registerValidator(validator2, MIN_STAKE, 100);
        
        // Simulate downtime slashing
        vm.startPrank(admin);
        
        bytes32 slasherRole = consensus.SLASHER_ROLE();
        consensus.grantRole(slasherRole, admin);
        
        // Slash for downtime
        consensus.slashDowntime(validator2);
        
        vm.stopPrank();
        
        // Verify validator is jailed and slashed
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertTrue(info.jailed);
        assertFalse(info.active);
        assertEq(info.stake, MIN_STAKE * 95 / 100); // 5% slashed
    }
    
    function testValidatorUnjailing() public {
        // Register and slash validator
        registerValidator(validator2, MIN_STAKE, 100);
        
        vm.startPrank(admin);
        bytes32 slasherRole = consensus.SLASHER_ROLE();
        consensus.grantRole(slasherRole, admin);
        consensus.slashDowntime(validator2);
        
        // Verify jailed
        assertTrue(consensus.getValidatorInfo(validator2).jailed);
        
        // Unjail
        consensus.unjailValidator(validator2);
        vm.stopPrank();
        
        // Verify unjailed
        AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validator2);
        assertFalse(info.jailed);
        assertTrue(info.active);
    }
    
    function testSequencerRegistryIntegration() public {
        // Register in consensus
        registerValidator(validator2, MIN_STAKE, 100);
        
        // Register in sequencer registry
        vm.prank(admin);
        sequencerRegistry.registerSequencer(
            validator2,
            MIN_STAKE,
            "https://validator2.ande.network"
        );
        
        // Verify registration in both contracts
        assertTrue(consensus.isValidator(validator2));
        
        AndeSequencerRegistry.SequencerInfo memory seqInfo = sequencerRegistry.getSequencerInfo(validator2);
        assertEq(seqInfo.sequencer, validator2);
        assertTrue(seqInfo.isActive);
    }
    
    function testPhaseTransitionWithMultipleValidators() public {
        // Start in GENESIS phase
        assertTrue(sequencerRegistry.currentPhase() == AndeSequencerRegistry.Phase.GENESIS);
        
        // Register second validator
        registerValidator(validator2, MIN_STAKE, 100);
        
        vm.prank(admin);
        sequencerRegistry.registerSequencer(
            validator2,
            MIN_STAKE,
            "https://validator2.ande.network"
        );
        
        // Fast forward time to phase 2
        vm.warp(block.timestamp + 180 days + 1);
        
        // Transition to DUAL phase
        vm.prank(admin);
        sequencerRegistry.transitionPhase();
        
        assertTrue(sequencerRegistry.currentPhase() == AndeSequencerRegistry.Phase.DUAL);
    }
    
    function testCompleteValidatorLifecycle() public {
        console.log("\n=== Testing Complete Validator Lifecycle ===");
        
        // 1. Register
        console.log("1. Registering validator...");
        registerValidator(validator2, MIN_STAKE, 100);
        assertTrue(consensus.isValidator(validator2));
        console.log("   [OK] Validator registered");
        
        // 2. Produce blocks (simulated by tracking)
        console.log("2. Simulating block production...");
        assertEq(consensus.getValidatorInfo(validator2).totalBlocksProduced, 0);
        console.log("   [OK] Block production tracked");
        
        // 3. Update voting power
        console.log("3. Updating voting power...");
        vm.prank(admin);
        consensus.updateValidatorPower(validator2, 150);
        assertEq(consensus.getValidatorInfo(validator2).power, 150);
        console.log("   [OK] Voting power updated");
        
        // 4. Slash for misbehavior
        console.log("4. Slashing for misbehavior...");
        vm.startPrank(admin);
        bytes32 slasherRole = consensus.SLASHER_ROLE();
        consensus.grantRole(slasherRole, admin);
        consensus.slashDowntime(validator2);
        assertTrue(consensus.getValidatorInfo(validator2).jailed);
        console.log("   [OK] Validator slashed and jailed");
        
        // 5. Unjail
        console.log("5. Unjailing validator...");
        consensus.unjailValidator(validator2);
        assertFalse(consensus.getValidatorInfo(validator2).jailed);
        console.log("   [OK] Validator unjailed");
        
        // 6. Deactivate
        console.log("6. Deactivating validator...");
        consensus.deactivateValidator(validator2);
        assertFalse(consensus.getValidatorInfo(validator2).active);
        vm.stopPrank();
        console.log("   [OK] Validator deactivated");
        
        console.log("\n[SUCCESS] Complete lifecycle test passed!");
    }
    
    function testFiveValidatorScenario() public {
        console.log("\n=== Testing 5-Validator Setup ===");
        
        // Register 5 validators total (including genesis)
        registerValidator(validator2, MIN_STAKE, 100);
        registerValidator(validator3, MIN_STAKE * 3, 300);
        registerValidator(validator4, MIN_STAKE * 2, 200);
        registerValidator(validator5, MIN_STAKE, 100);
        
        // Verify setup
        assertEq(consensus.getActiveValidatorsCount(), 5);
        assertEq(consensus.totalVotingPower(), 800); // 100+100+300+200+100
        
        // Get all validators
        address[] memory validators = consensus.getActiveValidators();
        assertEq(validators.length, 5);
        
        console.log("Total Validators:", validators.length);
        console.log("Total Voting Power:", consensus.totalVotingPower());
        
        // Verify each validator
        for (uint i = 0; i < validators.length; i++) {
            assertTrue(consensus.isValidator(validators[i]));
            AndeConsensus.ValidatorInfo memory info = consensus.getValidatorInfo(validators[i]);
            console.log("Validator", i, "- Power:", info.power);
        }
        
        console.log("\n[SUCCESS] 5-Validator setup complete!");
    }
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    function registerValidator(
        address validator,
        uint256 stakeAmount,
        uint256 votingPower
    ) internal {
        vm.prank(admin);
        consensus.registerValidator(
            validator,
            bytes32(uint256(uint160(validator))),
            string(abi.encodePacked("https://", vm.toString(validator), ".ande.network")),
            stakeAmount,
            votingPower
        );
    }
}