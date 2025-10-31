// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AndeGovernor} from "../../../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../../../src/governance/AndeTimelockController.sol";
import {ANDETokenDuality} from "../../../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../../../src/staking/AndeNativeStaking.sol";
import {IAndeNativeStaking} from "../../../src/governance/extensions/GovernorDualTokenVoting.sol";
import {GovernorSecurityExtensions} from "../../../src/governance/extensions/GovernorSecurityExtensions.sol";
import {NativeTransferPrecompileMock} from "../../../src/mocks/NativeTransferPrecompileMock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GovernorSecurityExtensionsTest is Test {
    AndeGovernor public governor;
    AndeTimelockController public timelock;
    ANDETokenDuality public andeToken;
    AndeNativeStaking public staking;
    NativeTransferPrecompileMock public precompileMock;

    address public admin = address(0x1);
    address public emergencyCouncil = address(0x5);
    address public guardian = address(0x6);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public whale = address(0x7);

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    uint32 public constant VOTING_PERIOD = 50400;
    uint48 public constant VOTING_DELAY = 1;
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 ether;

    function setUp() public {
        vm.startPrank(admin);

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

        AndeNativeStaking stakingImpl = new AndeNativeStaking();
        bytes memory stakingInit = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            admin,
            admin
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInit);
        staking = AndeNativeStaking(address(stakingProxy));

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

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, admin);

        andeToken.mint(user1, 500_000_000 ether);
        andeToken.mint(user2, 300_000_000 ether);
        andeToken.mint(whale, 150_000_000 ether);

        vm.stopPrank();

        vm.prank(user1);
        andeToken.delegate(user1);
        
        vm.prank(user2);
        andeToken.delegate(user2);
        
        vm.prank(whale);
        andeToken.delegate(whale);

        vm.roll(block.number + 1);
    }

    function testAntiWhaleVotingPowerCap() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Test anti-whale protection"
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        uint256 totalSupply = andeToken.totalSupply();
        uint256 maxAllowedVotes = (totalSupply * 10) / 100;
        uint256 user1RawVotingPower = governor.getVotes(user1, block.number - 1);
        
        assertGt(user1RawVotingPower, maxAllowedVotes, "User1 should have more than 10% raw voting power");
        
        vm.expectEmit(true, true, true, true);
        emit GovernorSecurityExtensions.VotingPowerCapped(user1, user1RawVotingPower, maxAllowedVotes);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        assertEq(forVotes, maxAllowedVotes, "Actual vote weight should be capped at 10%");
        assertEq(againstVotes, 0, "No against votes");
        assertEq(abstainVotes, 0, "No abstain votes");
    }

    function testProposalCooldown() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.startPrank(user1);
        
        governor.propose(targets, values, calldatas, "First proposal");
        
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Second proposal immediately");
        
        vm.warp(block.timestamp + 1 days + 1);
        
        uint256 secondProposalId = governor.propose(targets, values, calldatas, "Second proposal after cooldown");
        assertGt(secondProposalId, 0, "Second proposal should succeed after cooldown");
        
        vm.stopPrank();
    }

    function testGuardianCancellation() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Malicious proposal"
        );
        
        vm.prank(guardian);
        governor.guardianCancel(targets, values, calldatas, keccak256(bytes("Malicious proposal")), "Malicious behavior detected");
        
        IGovernor.ProposalState state = governor.state(proposalId);
        assertEq(uint8(state), uint8(IGovernor.ProposalState.Canceled), "Proposal should be canceled");
    }

    function testGuardianCancellationOnlyByGuardian() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        vm.prank(user1);
        governor.propose(
            targets,
            values,
            calldatas,
            "Some proposal"
        );
        
        vm.prank(user2);
        vm.expectRevert(GovernorSecurityExtensions.UnauthorizedGuardian.selector);
        governor.guardianCancel(targets, values, calldatas, keccak256(bytes("Some proposal")), "Attempted cancellation");
    }

    function testUpdateGuardian() public {
        address newGuardian = address(0x888);
        
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateGuardian(address)", newGuardian);
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Update guardian");
        
        assertGt(proposalId, 0, "Proposal should be created");
    }

    function testGetGuardian() public view {
        address currentGuardian = GovernorSecurityExtensions(payable(address(governor))).guardian();
        assertEq(currentGuardian, guardian, "Guardian should match initialization");
    }

    function testCooldownDoesNotAffectDifferentUsers() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(user1);
        uint256 proposal1 = governor.propose(targets, values, calldatas, "User1 proposal");
        
        vm.prank(user2);
        uint256 proposal2 = governor.propose(targets, values, calldatas, "User2 proposal");
        
        assertGt(proposal1, 0, "User1 proposal should succeed");
        assertGt(proposal2, 0, "User2 proposal should succeed immediately");
    }
}
