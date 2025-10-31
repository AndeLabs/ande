// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AndeGovernor} from "../../../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../../../src/governance/AndeTimelockController.sol";
import {ANDETokenDuality} from "../../../src/ANDETokenDuality.sol";
import {AndeNativeStaking} from "../../../src/staking/AndeNativeStaking.sol";
import {IAndeNativeStaking} from "../../../src/governance/extensions/GovernorDualTokenVoting.sol";
import {NativeTransferPrecompileMock} from "../../../src/mocks/NativeTransferPrecompileMock.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AndeGovernorTest is Test {
    AndeGovernor public governor;
    AndeTimelockController public timelock;
    ANDETokenDuality public andeToken;
    AndeNativeStaking public staking;
    NativeTransferPrecompileMock public precompileMock;

    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public emergencyCouncil = address(0x5);
    address public guardian = address(0x6);

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    uint32 public constant VOTING_PERIOD = 50400;
    uint48 public constant VOTING_DELAY = 1;
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 ether;

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

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

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        andeToken.mint(user1, 500_000 ether);
        andeToken.mint(user2, 300_000 ether);
        andeToken.mint(user3, 200_000 ether);

        vm.stopPrank();

        vm.prank(user1);
        andeToken.delegate(user1);
        vm.prank(user2);
        andeToken.delegate(user2);
        vm.prank(user3);
        andeToken.delegate(user3);

        vm.roll(block.number + 1);
    }

    function testInitialization() public view {
        assertEq(governor.name(), "AndeGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
    }

    function testDualTokenVotingBaseOnly() public {
        uint256 votingPower = governor.getCurrentVotes(user1);
        
        assertEq(votingPower, 500_000 ether, "Should equal base votes when no staking");
    }

    function testDualTokenVotingWithStaking() public {
        vm.startPrank(user1);
        
        andeToken.approve(address(staking), 100_000 ether);
        staking.stakeGovernance(100_000 ether, AndeNativeStaking.LockPeriod.TWELVE_MONTHS);
        
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + 2 hours);
        
        uint256 votingPower = governor.getCurrentVotes(user1);
        
        assertGt(votingPower, 500_000 ether, "Voting power should be greater with staking");
        
        vm.stopPrank();
    }

    function testDualTokenVotingBreakdown() public {
        vm.startPrank(user1);
        
        andeToken.approve(address(staking), 100_000 ether);
        staking.stakeGovernance(100_000 ether, AndeNativeStaking.LockPeriod.TWENTY_FOUR_MONTHS);
        
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + 2 hours);
        
        (uint256 baseVotes, uint256 stakingBonus, uint256 totalVotes) = 
            governor.getVotesWithStaking(user1, block.number - 1);
        
        assertEq(baseVotes, 400_000 ether, "Base votes should be from token delegation (500k - 100k staked)");
        assertGt(stakingBonus, 0, "Staking bonus should exist");
        assertEq(totalVotes, baseVotes + stakingBonus, "Total should equal sum");
        
        vm.stopPrank();
    }

    function testAntiWhaleProtection() public {
        vm.startPrank(user1);
        
        andeToken.approve(address(staking), 500_000 ether);
        staking.stakeGovernance(500_000 ether, AndeNativeStaking.LockPeriod.TWENTY_FOUR_MONTHS);
        
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + 2 hours);
        
        (uint256 baseVotes, uint256 stakingBonus, uint256 totalVotes) = 
            governor.getVotesWithStaking(user1, block.number - 1);
        
        uint256 maxBonus = (baseVotes * 50000) / 10000;
        assertLe(stakingBonus, maxBonus, "Staking bonus should be capped at 500%");
        
        vm.stopPrank();
    }

    function testCreateProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        string memory description = "Pause ANDE token for emergency";
        
        vm.startPrank(user1);
        
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        assertGt(proposalId, 0, "Proposal ID should be generated");
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));
        
        vm.stopPrank();
    }

    function testProposalRequiresThreshold() public {
        vm.prank(admin);
        andeToken.mint(address(0x999), 50_000 ether);
        
        vm.prank(address(0x999));
        andeToken.delegate(address(0x999));
        
        vm.roll(block.number + 1);
        
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("pause()");
        
        vm.prank(address(0x999));
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Test proposal");
    }

    function testVoteOnProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("unpause()");
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        assertGt(forVotes, 0, "Should have votes for");
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testQuorumRequirement() public view {
        uint256 quorum = governor.quorum(block.number - 1);
        uint256 totalSupply = andeToken.totalSupply();
        
        uint256 initialQuorum = (totalSupply * 1500) / 10000;
        
        assertEq(quorum, initialQuorum, "Initial quorum should be 15% (no history)");
    }

    function testStakingContractUpdate() public {
        AndeNativeStaking newStakingImpl = new AndeNativeStaking();
        bytes memory newStakingInit = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            admin,
            admin
        );
        ERC1967Proxy newStakingProxy = new ERC1967Proxy(address(newStakingImpl), newStakingInit);
        AndeNativeStaking newStaking = AndeNativeStaking(address(newStakingProxy));
        
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "updateStakingContract(address)",
            address(newStaking)
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Update staking contract");
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        vm.prank(user3);
        governor.castVote(proposalId, 1);
        
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        bytes32 descriptionHash = keccak256(bytes("Update staking contract"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        governor.execute(targets, values, calldatas, descriptionHash);
        
        assertEq(address(governor.stakingContract()), address(newStaking));
    }

    function testCannotUpdateStakingContractWithoutGovernance() public {
        AndeNativeStaking newStakingImpl = new AndeNativeStaking();
        bytes memory newStakingInit = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            address(andeToken),
            admin,
            admin
        );
        ERC1967Proxy newStakingProxy = new ERC1967Proxy(address(newStakingImpl), newStakingInit);
        AndeNativeStaking newStaking = AndeNativeStaking(address(newStakingProxy));
        
        vm.prank(user1);
        vm.expectRevert();
        governor.updateStakingContract(IAndeNativeStaking(address(newStaking)));
    }

    function testGetStakingInfo() public {
        vm.startPrank(user1);
        
        andeToken.approve(address(staking), 100_000 ether);
        staking.stakeGovernance(100_000 ether, AndeNativeStaking.LockPeriod.SIX_MONTHS);
        
        vm.roll(block.number + 1);
        
        IAndeNativeStaking.StakeInfo memory info = governor.getStakingInfo(user1);
        
        assertEq(info.amount, 100_000 ether);
        assertEq(uint8(info.level), uint8(AndeNativeStaking.StakingLevel.GOVERNANCE));
        assertEq(uint8(info.lockPeriod), uint8(AndeNativeStaking.LockPeriod.SIX_MONTHS));
        assertGt(info.votingPower, 0);
        assertFalse(info.isSequencer);
        
        vm.stopPrank();
    }

    function testAdaptiveQuorumInitialState() public view {
        uint256 quorumBps = governor.getCurrentQuorumBps();
        uint256 avgParticipation = governor.getAverageParticipation();
        
        assertEq(quorumBps, 1500, "Initial quorum should be 15% (1500 bps)");
        assertEq(avgParticipation, 1500, "Initial avg participation should be 15%");
    }

    function testAdaptiveQuorumAdjustsWithHighParticipation() public {
        _createAndExecuteProposalWithCounter(0, true);
        
        uint256 quorumAfterOne = governor.getCurrentQuorumBps();
        uint256 avgParticipationAfterOne = governor.getAverageParticipation();
        
        assertLt(quorumAfterOne, 1500, "Quorum should decrease after first high participation proposal");
        assertGt(avgParticipationAfterOne, 0, "Should have participation data");
    }

    function testAdaptiveQuorumHistory() public {
        uint256 historyCount = governor.getParticipationHistoryCount();
        assertEq(historyCount, 0, "Should start with empty history");
        
        _createAndExecuteProposalWithCounter(0, true);
        
        historyCount = governor.getParticipationHistoryCount();
        assertEq(historyCount, 1, "Should have 1 entry after execution");
    }

    function _createAndExecuteProposal(bool voteAndExecute) internal returns (uint256) {
        return _createAndExecuteProposalWithCounter(0, voteAndExecute);
    }
    
    function _createAndExecuteProposalWithCounter(uint256 counter, bool voteAndExecute) internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("name()");
        
        string memory description = string(abi.encodePacked("Test adaptive quorum proposal #", vm.toString(counter)));
        
        uint256 currentBlock = block.number;
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        if (voteAndExecute) {
            vm.roll(currentBlock + VOTING_DELAY + 1);
            
            vm.prank(user1);
            governor.castVote(proposalId, 1);
            vm.prank(user2);
            governor.castVote(proposalId, 1);
            vm.prank(user3);
            governor.castVote(proposalId, 1);
            
            vm.roll(currentBlock + VOTING_DELAY + VOTING_PERIOD + 2);
            
            bytes32 descriptionHash = keccak256(bytes(description));
            governor.queue(targets, values, calldatas, descriptionHash);
            
            vm.warp(block.timestamp + 2 days + 1);
            
            governor.execute(targets, values, calldatas, descriptionHash);
            
            vm.roll(currentBlock + VOTING_DELAY + VOTING_PERIOD + 3);
        }
        
        return proposalId;
    }
}
