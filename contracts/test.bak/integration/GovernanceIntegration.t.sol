// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AndeGovernor} from "../../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../../src/governance/AndeTimelockController.sol";
import {ANDETokenDuality} from "../../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../../src/staking/AndeNativeStaking.sol";
import {AndeFeeDistributor} from "../../src/tokenomics/AndeFeeDistributor.sol";
import {CommunityTreasury} from "../../src/community/CommunityTreasury.sol";
import {AndeRollupGovernance, IAndeSequencerRegistry} from "../../src/governance/AndeRollupGovernance.sol";
import {IAndeNativeStaking} from "../../src/governance/extensions/GovernorDualTokenVoting.sol";
import {GovernorMultiLevel} from "../../src/governance/extensions/GovernorMultiLevel.sol";
import {NativeTransferPrecompileMock} from "../../src/mocks/NativeTransferPrecompileMock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
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
}

/**
 * @title GovernanceIntegrationTest
 * @notice Tests de integración end-to-end para el sistema de governance completo
 * @dev Demuestra cómo governance controla todo el ecosistema
 */
contract GovernanceIntegrationTest is Test {
    AndeGovernor public governor;
    AndeTimelockController public timelock;
    ANDETokenDuality public andeToken;
    AndeNativeStaking public staking;
    AndeFeeDistributor public feeDistributor;
    CommunityTreasury public communityTreasury;
    AndeRollupGovernance public rollupGov;
    MockSequencerRegistry public sequencerRegistry;
    NativeTransferPrecompileMock public precompileMock;
    
    address public admin = address(0x1);
    address public emergencyCouncil = address(0x5);
    address public guardian = address(0x6);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public protocolTreasury = address(0x7);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    uint32 public constant VOTING_PERIOD = 50400;
    uint48 public constant VOTING_DELAY = 1;
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 ether;
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy ANDE Token
        ANDETokenDuality implementation = new ANDETokenDuality();
        address placeholder = address(0x1234);
        precompileMock = new NativeTransferPrecompileMock(placeholder);
        
        bytes memory initData = abi.encodeWithSelector(
            ANDETokenDuality.initialize.selector, 
            admin, 
            admin, 
            address(precompileMock)
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        andeToken = ANDETokenDuality(address(proxy));
        
        precompileMock = new NativeTransferPrecompileMock(address(andeToken));
        andeToken.setPrecompileAddress(address(precompileMock));
        
        // Deploy Staking
        AndeNativeStaking stakingImpl = new AndeNativeStaking();
        bytes memory stakingInit = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            admin,
            admin
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInit);
        staking = AndeNativeStaking(address(stakingProxy));
        
        // Deploy Timelock
        address[] memory proposers = new address[](1);
        proposers[0] = admin;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        
        AndeTimelockController timelockImpl = new AndeTimelockController();
        bytes memory timelockInit = abi.encodeWithSelector(
            AndeTimelockController.initialize.selector,
            2 days,
            proposers,
            executors,
            admin
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(address(timelockImpl), timelockInit);
        timelock = AndeTimelockController(payable(address(timelockProxy)));
        
        // Deploy Governor
        AndeGovernor governorImpl = new AndeGovernor();
        bytes memory governorInit = abi.encodeWithSelector(
            AndeGovernor.initialize.selector,
            IVotes(address(andeToken)),
            IAndeNativeStaking(address(staking)),
            timelock,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD,
            emergencyCouncil,
            guardian
        );
        ERC1967Proxy governorProxy = new ERC1967Proxy(address(governorImpl), governorInit);
        governor = AndeGovernor(payable(address(governorProxy)));
        
        // Setup timelock roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, admin);
        
        // Deploy CommunityTreasury
        CommunityTreasury treasuryImpl = new CommunityTreasury();
        bytes memory treasuryInit = abi.encodeWithSelector(
            CommunityTreasury.initialize.selector,
            address(andeToken),
            address(timelock)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImpl), treasuryInit);
        communityTreasury = CommunityTreasury(address(treasuryProxy));
        
        // Grant GOVERNOR_ROLE to timelock
        vm.startPrank(address(timelock));
        communityTreasury.grantRole(communityTreasury.GOVERNOR_ROLE(), address(timelock));
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Deploy SequencerRegistry
        sequencerRegistry = new MockSequencerRegistry();
        
        // Deploy FeeDistributor
        AndeFeeDistributor feeDistImpl = new AndeFeeDistributor();
        bytes memory feeDistInit = abi.encodeWithSelector(
            AndeFeeDistributor.initialize.selector,
            address(andeToken),
            address(sequencerRegistry),
            address(staking),
            protocolTreasury,
            address(communityTreasury),
            address(timelock)
        );
        ERC1967Proxy feeDistProxy = new ERC1967Proxy(address(feeDistImpl), feeDistInit);
        feeDistributor = AndeFeeDistributor(address(feeDistProxy));
        
        // Grant GOVERNOR_ROLE to timelock
        vm.startPrank(address(timelock));
        feeDistributor.grantRole(feeDistributor.GOVERNOR_ROLE(), address(timelock));
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Deploy RollupGovernance
        AndeRollupGovernance rollupImpl = new AndeRollupGovernance();
        bytes memory rollupInit = abi.encodeWithSelector(
            AndeRollupGovernance.initialize.selector,
            address(sequencerRegistry),
            address(timelock)
        );
        ERC1967Proxy rollupProxy = new ERC1967Proxy(address(rollupImpl), rollupInit);
        rollupGov = AndeRollupGovernance(address(rollupProxy));
        
        // Grant EMERGENCY_ROLE to timelock so it can pause/unpause
        vm.startPrank(address(timelock));
        rollupGov.grantRole(rollupGov.EMERGENCY_ROLE(), address(timelock));
        vm.stopPrank();
        
        vm.startPrank(admin);
        
        // Mint tokens to users
        andeToken.mint(user1, 500_000_000 ether);
        andeToken.mint(user2, 300_000_000 ether);
        
        // Fund community treasury
        andeToken.mint(admin, 50_000_000 ether);
        andeToken.approve(address(communityTreasury), 50_000_000 ether);
        communityTreasury.receiveFunds(50_000_000 ether);
        
        vm.stopPrank();
        
        // Delegate voting power
        vm.prank(user1);
        andeToken.delegate(user1);
        
        vm.prank(user2);
        andeToken.delegate(user2);
        
        vm.roll(block.number + 1);
    }
    
    /**
     * @notice Test: Governance actualiza configuración de fee distribution
     */
    function testGovernanceUpdatesFeeDistribution() public {
        address[] memory targets = new address[](1);
        targets[0] = address(feeDistributor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "updateDistributionConfig(uint256,uint256,uint256,uint256)",
            3500, // sequencer: 35%
            3500, // stakers: 35%
            2000, // protocol: 20%
            1000  // community: 10%
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Update fee distribution to increase staker rewards"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Update fee distribution to increase staker rewards"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        AndeFeeDistributor.FeeDistributionConfig memory config = feeDistributor.getDistributionConfig();
        assertEq(config.sequencerShare, 3500, "Sequencer share should be updated");
        assertEq(config.stakersShare, 3500, "Stakers share should be updated");
    }
    
    /**
     * @notice Test: Governance aprueba y ejecuta grant de community treasury
     */
    function testGovernanceApprovesGrant() public {
        address builder = address(0x999);
        uint256 grantAmount = 10_000 ether;
        
        address[] memory targets = new address[](2);
        targets[0] = address(communityTreasury);
        targets[1] = address(communityTreasury);
        
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature(
            "proposeAndApproveGrant(address,uint256,string,string,string,uint8)",
            builder,
            grantAmount,
            "DApp Development Grant",
            "Building innovative DeFi application",
            "QmHash123",
            uint8(0) // BUILDER_GRANT
        );
        calldatas[1] = abi.encodeWithSignature(
            "disburseGrant(uint256)",
            0 // grantId
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Approve grant for builder"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Approve grant for builder"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        uint256 balanceBefore = andeToken.balanceOf(builder);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        uint256 balanceAfter = andeToken.balanceOf(builder);
        assertEq(balanceAfter - balanceBefore, grantAmount, "Builder should receive grant");
        
        CommunityTreasury.GrantStats memory stats = communityTreasury.getGrantStats();
        assertEq(stats.totalApproved, 1, "Should have 1 approved grant");
        assertEq(stats.totalCompleted, 1, "Should have 1 completed grant");
    }
    
    /**
     * @notice Test: Governance agrega nuevo sequencer al rollup
     */
    function testGovernanceAddsSequencer() public {
        address newSequencer = address(0x888);
        uint256 stake = 100_000 ether;
        
        address[] memory targets = new address[](1);
        targets[0] = address(rollupGov);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "addSequencer(address,uint256)",
            newSequencer,
            stake
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Add new sequencer to network"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Add new sequencer to network"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        assertTrue(sequencerRegistry.sequencers(newSequencer), "Sequencer should be added");
        assertEq(sequencerRegistry.stakes(newSequencer), stake, "Stake should be set");
    }
    
    /**
     * @notice Test: Governance actualiza gas fees del rollup
     */
    function testGovernanceUpdatesRollupGasFees() public {
        address[] memory targets = new address[](2);
        targets[0] = address(rollupGov);
        targets[1] = address(rollupGov);
        
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("updateBaseFee(uint256)", 5 gwei);
        calldatas[1] = abi.encodeWithSignature("updatePriorityFee(uint256)", 2 gwei);
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Adjust rollup gas fees for network optimization"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Adjust rollup gas fees for network optimization"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        assertEq(rollupGov.baseFeePerGas(), 5 gwei, "Base fee should be updated");
        assertEq(rollupGov.priorityFeePerGas(), 2 gwei, "Priority fee should be updated");
    }
    
    /**
     * @notice Test: Governance puede pausar rollup con propuesta PROTOCOL
     */
    function testGovernanceCanPauseRollup() public {
        address[] memory targets = new address[](1);
        targets[0] = address(rollupGov);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergencyPause()");
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Pause rollup for maintenance"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Pause rollup for maintenance"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        assertTrue(rollupGov.paused(), "Rollup should be paused");
    }
    
    /**
     * @notice Test: Multi-target proposal actualiza múltiples contratos
     */
    function testMultiContractUpdate() public {
        address[] memory targets = new address[](3);
        targets[0] = address(feeDistributor);
        targets[1] = address(rollupGov);
        targets[2] = address(rollupGov);
        
        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        
        bytes[] memory calldatas = new bytes[](3);
        calldatas[0] = abi.encodeWithSignature(
            "updateDistributionConfig(uint256,uint256,uint256,uint256)",
            4500, 2500, 2000, 1000
        );
        calldatas[1] = abi.encodeWithSignature("updateBaseFee(uint256)", 10 gwei);
        calldatas[2] = abi.encodeWithSignature("updateSequencerCut(uint256)", 3500);
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Comprehensive network parameter update"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Comprehensive network parameter update"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        AndeFeeDistributor.FeeDistributionConfig memory config = feeDistributor.getDistributionConfig();
        assertEq(config.sequencerShare, 4500, "Fee distributor should be updated");
        assertEq(rollupGov.baseFeePerGas(), 10 gwei, "Rollup base fee should be updated");
        assertEq(rollupGov.sequencerCutBps(), 3500, "Rollup sequencer cut should be updated");
    }
    
    /**
     * @notice Test: Verifica que el sistema completo está integrado correctamente
     */
    function testFullSystemIntegration() public view {
        // Verify all contracts are deployed
        assertTrue(address(governor) != address(0), "Governor should be deployed");
        assertTrue(address(timelock) != address(0), "Timelock should be deployed");
        assertTrue(address(andeToken) != address(0), "Token should be deployed");
        assertTrue(address(staking) != address(0), "Staking should be deployed");
        assertTrue(address(feeDistributor) != address(0), "FeeDistributor should be deployed");
        assertTrue(address(communityTreasury) != address(0), "CommunityTreasury should be deployed");
        assertTrue(address(rollupGov) != address(0), "RollupGovernance should be deployed");
        
        // Verify timelock has roles
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)), "Governor should be proposer");
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), "Everyone should be executor");
        
        // Verify governance roles in managed contracts
        assertTrue(
            feeDistributor.hasRole(feeDistributor.GOVERNOR_ROLE(), address(timelock)),
            "Timelock should have governor role in FeeDistributor"
        );
        assertTrue(
            communityTreasury.hasRole(communityTreasury.GOVERNOR_ROLE(), address(timelock)),
            "Timelock should have governor role in CommunityTreasury"
        );
        assertTrue(
            rollupGov.hasRole(rollupGov.GOVERNOR_ROLE(), address(timelock)),
            "Timelock should have governor role in RollupGovernance"
        );
    }
}
