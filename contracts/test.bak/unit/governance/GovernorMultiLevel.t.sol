// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AndeGovernor} from "../../../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../../../src/governance/AndeTimelockController.sol";
import {ANDETokenDuality} from "../../../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../../../src/staking/AndeNativeStaking.sol";
import {IAndeNativeStaking} from "../../../src/governance/extensions/GovernorDualTokenVoting.sol";
import {GovernorMultiLevel} from "../../../src/governance/extensions/GovernorMultiLevel.sol";
import {NativeTransferPrecompileMock} from "../../../src/mocks/NativeTransferPrecompileMock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GovernorMultiLevelTest is Test {
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
        andeToken.mint(emergencyCouncil, 100_000_000 ether);

        vm.stopPrank();

        vm.prank(user1);
        andeToken.delegate(user1);
        
        vm.prank(user2);
        andeToken.delegate(user2);
        
        vm.prank(emergencyCouncil);
        andeToken.delegate(emergencyCouncil);

        vm.roll(block.number + 1);
    }

    function testOperationalProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(user1);
        uint256 proposalId = governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Operational proposal",
            GovernorMultiLevel.ProposalType.OPERATIONAL
        );
        
        assertGt(proposalId, 0, "Proposal should be created");
        
        GovernorMultiLevel.ProposalType pType = GovernorMultiLevel(payable(address(governor))).getProposalType(proposalId);
        assertEq(uint8(pType), uint8(GovernorMultiLevel.ProposalType.OPERATIONAL));
    }

    function testProtocolProposal() public {
        vm.prank(user1);
        andeToken.transfer(user2, 200_000_000 ether);
        
        vm.roll(block.number + 1);
        
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(user2);
        uint256 proposalId = governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Protocol proposal",
            GovernorMultiLevel.ProposalType.PROTOCOL
        );
        
        assertGt(proposalId, 0, "Proposal should be created");
        
        GovernorMultiLevel.ProposalType pType = GovernorMultiLevel(payable(address(governor))).getProposalType(proposalId);
        assertEq(uint8(pType), uint8(GovernorMultiLevel.ProposalType.PROTOCOL));
    }

    function testCriticalProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(user1);
        uint256 proposalId = governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Critical proposal",
            GovernorMultiLevel.ProposalType.CRITICAL
        );
        
        assertGt(proposalId, 0, "Proposal should be created");
        
        GovernorMultiLevel.ProposalType pType = GovernorMultiLevel(payable(address(governor))).getProposalType(proposalId);
        assertEq(uint8(pType), uint8(GovernorMultiLevel.ProposalType.CRITICAL));
    }

    function testEmergencyProposalByCouncil() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        vm.prank(emergencyCouncil);
        uint256 proposalId = governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Emergency proposal",
            GovernorMultiLevel.ProposalType.EMERGENCY
        );
        
        assertGt(proposalId, 0, "Emergency proposal should be created");
        
        GovernorMultiLevel.ProposalType pType = GovernorMultiLevel(payable(address(governor))).getProposalType(proposalId);
        assertEq(uint8(pType), uint8(GovernorMultiLevel.ProposalType.EMERGENCY));
    }

    function testEmergencyProposalOnlyByCouncil() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        vm.prank(user1);
        vm.expectRevert(GovernorMultiLevel.UnauthorizedEmergencyProposal.selector);
        governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Emergency proposal",
            GovernorMultiLevel.ProposalType.EMERGENCY
        );
    }

    function testProtocolProposalRequiresHigherThreshold() public {
        vm.prank(admin);
        andeToken.mint(address(0x999), 2_000_000 ether);
        
        vm.prank(address(0x999));
        andeToken.delegate(address(0x999));
        
        vm.roll(block.number + 1);
        
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        vm.prank(address(0x999));
        vm.expectRevert();
        governor.proposeWithType(
            targets,
            values,
            calldatas,
            "Protocol proposal with insufficient votes",
            GovernorMultiLevel.ProposalType.PROTOCOL
        );
    }

    function testGetProposalLevelConfiguration() public view {
        GovernorMultiLevel.ProposalLevel memory operationalLevel = GovernorMultiLevel(payable(address(governor))).getProposalLevel(
            GovernorMultiLevel.ProposalType.OPERATIONAL
        );
        
        assertEq(operationalLevel.threshold, 1_000_000 ether);
        assertEq(operationalLevel.votingDelay, 1 days);
        assertEq(operationalLevel.votingPeriod, 3 days);
        assertEq(operationalLevel.quorumBps, 400);
    }

    function testUpdateEmergencyCouncil() public {
        address newCouncil = address(0x777);
        
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("updateEmergencyCouncil(address)", newCouncil);
        
        vm.prank(user1);
        governor.propose(targets, values, calldatas, "Update emergency council");
    }
}
