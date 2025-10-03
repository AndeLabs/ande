// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MintController} from "../src/MintController.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {VeANDE} from "../src/VeANDE.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MintControllerTest is Test {
    // --- Contracts ---
    MintController public controller;
    ANDEToken public andeToken;
    VeANDE public veANDE;

    // --- Users ---
    address public admin = makeAddr("admin");
    address public governance = makeAddr("governance");
    address public guardian = makeAddr("guardian");
    address public recipient = makeAddr("recipient");
    address public maliciousUser = makeAddr("maliciousUser");

    // --- Constants ---
    uint256 public constant HARD_CAP = 1_500_000_000 * 1e18;
    uint256 public constant ANNUAL_LIMIT = 50_000_000 * 1e18;
    uint256 public constant MINT_AMOUNT = 5_000_000 * 1e18;

    // --- Roles ---
    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // --- Modifier to set up voters ---
    modifier givenVotersHaveLocked() {
        address[] memory voters = new address[](4);
        voters[0] = makeAddr("voter1");
        voters[1] = makeAddr("voter2");
        voters[2] = makeAddr("voter3");
        voters[3] = makeAddr("voter4");

        uint256 lockAmount = 100_000 * 1e18;
        uint256 unlockTime = block.timestamp + 4 * 365 days;

        for (uint i = 0; i < voters.length; i++) {
            address voter = voters[i];
            // The test contract itself is the admin/minter of andeToken
            andeToken.mint(voter, lockAmount);
            
            vm.startPrank(voter);
            andeToken.approve(address(veANDE), lockAmount);
            veANDE.createLock(lockAmount, unlockTime);
            vm.stopPrank();
        }
        // Advance 1 block to ensure votes are registered for the next block's snapshot
        vm.roll(block.number + 1);
        _;
    }

    function setUp() public {
        // --- Deploy Contracts ---
        // Grant admin role to the test contract itself for easier role management
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, address(this), address(this)))));
        veANDE = VeANDE(address(new ERC1967Proxy(address(new VeANDE()), abi.encodeWithSelector(VeANDE.initialize.selector, address(this), address(andeToken)))));
        
        controller = MintController(address(new ERC1967Proxy(address(new MintController()), abi.encodeWithSelector(
            MintController.initialize.selector,
            address(this), // Make test contract the admin
            governance,
            guardian,
            address(andeToken),
            address(veANDE),
            HARD_CAP,
            ANNUAL_LIMIT
        ))));

        // --- Grant Minter Role ---
        // Now the test contract itself can grant roles on andeToken
        andeToken.grantRole(andeToken.MINTER_ROLE(), address(controller));
    }

    // --- Test Group 1: Deployment and Initialization ---

    function test_Deployment_InitializesCorrectly() public view {
        assertEq(address(controller.andeToken()), address(andeToken), "andeToken address mismatch");
        assertEq(address(controller.veANDE()), address(veANDE), "veANDE address mismatch");
        assertEq(controller.hardCap(), HARD_CAP, "hardCap mismatch");
        assertEq(controller.annualMintLimit(), ANNUAL_LIMIT, "annualMintLimit mismatch");
    }

    function test_Deployment_HasCorrectRoles() public view {
        assertTrue(controller.hasRole(ADMIN_ROLE, address(this)), "Admin role not set for test contract");
        assertTrue(controller.hasRole(GOVERNANCE_ROLE, governance), "Governance role not set");
        assertTrue(controller.hasRole(GUARDIAN_ROLE, guardian), "Guardian role not set");
    }

    // --- Test Group 2: Proposal Creation ---

    function test_Proposal_CanCreateProposal() public givenVotersHaveLocked {
        string memory description = "Fund Q1 2025 ecosystem grants program";
        uint256 proposalId;

        vm.prank(governance);
        proposalId = controller.createProposal(MINT_AMOUNT, recipient, description);
        assertEq(proposalId, 1);

        (uint256 amount, address recipientAddr, string memory desc) = controller.getProposalCore(proposalId);
        assertEq(amount, MINT_AMOUNT);
        assertEq(recipientAddr, recipient);
        assertEq(desc, description);
    }

    function test_Proposal_Fail_NonGovernanceCannotCreate() public {
        vm.prank(maliciousUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, maliciousUser, GOVERNANCE_ROLE)
        );
        controller.createProposal(MINT_AMOUNT, recipient, "Malicious proposal");
    }

    // --- Test Group 3: Voting Mechanics ---

    modifier givenProposalIsActive() {
        vm.prank(governance);
        controller.createProposal(MINT_AMOUNT, recipient, "Test proposal");
        _;
    }

    function test_Voting_CanCastVoteFor() public givenVotersHaveLocked givenProposalIsActive {
        address voter = makeAddr("voter1");
        uint256 proposalId = 1;
        (uint256 snapshotBlock, , , ) = controller.getProposalTimestamps(proposalId);
        uint256 votePower = veANDE.getPastVotes(voter, snapshotBlock);
        assertTrue(votePower > 0, "Voter should have power");

        (uint256 beforeVotesFor, ,) = controller.getProposalVotes(proposalId);

        vm.prank(voter);
        controller.castVote(proposalId, true);

        assertTrue(controller.hasVoted(proposalId, voter), "Should have recorded vote");
        (uint256 afterVotesFor, ,) = controller.getProposalVotes(proposalId);
        assertEq(afterVotesFor, beforeVotesFor + votePower, "VotesFor should increase by voter's power");
    }

    function test_Voting_CanCastVoteAgainst() public givenVotersHaveLocked givenProposalIsActive {
        address voter = makeAddr("voter1");
        uint256 proposalId = 1;
        (uint256 snapshotBlock, , , ) = controller.getProposalTimestamps(proposalId);
        uint256 votePower = veANDE.getPastVotes(voter, snapshotBlock);

        ( , uint256 beforeVotesAgainst, ) = controller.getProposalVotes(proposalId);

        vm.prank(voter);
        controller.castVote(proposalId, false);

        ( , uint256 afterVotesAgainst, ) = controller.getProposalVotes(proposalId);
        assertEq(afterVotesAgainst, beforeVotesAgainst + votePower, "VotesAgainst should increase");
    }

    function test_Voting_Fail_CannotVoteTwice() public givenVotersHaveLocked givenProposalIsActive {
        address voter = makeAddr("voter1");
        uint256 proposalId = 1;

        vm.prank(voter);
        controller.castVote(proposalId, true);

        vm.prank(voter);
        vm.expectRevert(MintController.AlreadyVoted.selector);
        controller.castVote(proposalId, true);
    }

    // --- Test Group 4: Proposal States and Lifecycle ---

    // Helper to get voters for reuse
    function _getVoters() internal returns (address[] memory) {
        address[] memory voters = new address[](4);
        voters[0] = makeAddr("voter1");
        voters[1] = makeAddr("voter2");
        voters[2] = makeAddr("voter3");
        voters[3] = makeAddr("voter4");
        return voters;
    }

    function test_State_TransitionsToSucceeded() public givenVotersHaveLocked givenProposalIsActive {
        uint256 proposalId = 1;
        address[] memory voters = _getVoters();

        // 3 of 4 voters approve, reaching supermajority
        vm.prank(voters[0]);
        controller.castVote(proposalId, true);
        vm.prank(voters[1]);
        controller.castVote(proposalId, true);
        vm.prank(voters[2]);
        controller.castVote(proposalId, true);

        // Advance time past voting period
        uint256 votingPeriod = controller.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);

        // State should now be Succeeded
        assertEq(uint(controller.getProposalState(proposalId)), 3, "State should be Succeeded");
    }

    function test_State_TransitionsToQueued() public givenVotersHaveLocked givenProposalIsActive {
        uint256 proposalId = 1;
        address[] memory voters = _getVoters();

        // Pass the proposal
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(proposalId, true);
        }

        // Advance time and queue it
        uint256 votingPeriod = controller.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        
        controller.queueProposal(proposalId);

        // State should now be Queued
        assertEq(uint(controller.getProposalState(proposalId)), 4, "State should be Queued");
    }

    // --- Test Group 5: Timelock and Execution ---

    // Helper to vote, pass, and queue a proposal
    function _passAndQueueProposal(uint256 proposalId) internal {
        address[] memory voters = _getVoters();
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(proposalId, true);
        }

        uint256 votingPeriod = controller.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        
        controller.queueProposal(proposalId);
    }

    function test_Execution_Fail_CannotExecuteBeforeTimelock() public givenVotersHaveLocked givenProposalIsActive {
        uint256 proposalId = 1;
        _passAndQueueProposal(proposalId);

        vm.prank(governance);
        vm.expectRevert(MintController.ProposalTimelockNotMet.selector);
        controller.executeProposal(proposalId);
    }

    function test_Execution_CanExecuteAfterTimelock() public givenVotersHaveLocked givenProposalIsActive {
        uint256 proposalId = 1;
        _passAndQueueProposal(proposalId);

        uint256 executionDelay = controller.executionDelay();
        vm.warp(block.timestamp + executionDelay + 1);

        uint256 initialBalance = andeToken.balanceOf(recipient);

        vm.prank(governance);
        vm.expectEmit(true, true, true, false);
        emit MintController.ProposalExecuted(proposalId, MINT_AMOUNT, recipient);

        controller.executeProposal(proposalId);

        uint256 finalBalance = andeToken.balanceOf(recipient);
        assertEq(finalBalance - initialBalance, MINT_AMOUNT, "Recipient should receive minted tokens");
    }

    // --- Test Group 6: Economic Limits ---

    function test_Limits_EnforceAnnualLimit() public givenVotersHaveLocked {
        uint256 maxProposals = controller.annualMintLimit() / MINT_AMOUNT;

        for (uint i = 0; i < maxProposals; i++) {
            uint256 proposalId = i + 1;
            vm.prank(governance);
            controller.createProposal(MINT_AMOUNT, recipient, "Prop");
            _passAndQueueProposal(proposalId);
            uint256 executionDelay = controller.executionDelay();
            vm.warp(block.timestamp + executionDelay + 1);
            vm.prank(governance);
            controller.executeProposal(proposalId);
        }

        // Next proposal should fail
        vm.prank(governance);
        vm.expectRevert(MintController.ExceedsAnnualLimit.selector);
        controller.createProposal(MINT_AMOUNT, recipient, "Over limit");
    }

    function test_Limits_AnnualLimitResets() public givenVotersHaveLocked {
        // Execute one proposal in Year 1
        vm.prank(governance);
        controller.createProposal(MINT_AMOUNT, recipient, "Prop 1");
        _passAndQueueProposal(1);
        uint256 executionDelay = controller.executionDelay();
        vm.warp(block.timestamp + executionDelay + 1);
        vm.prank(governance);
        controller.executeProposal(1);

        assertEq(andeToken.balanceOf(recipient), MINT_AMOUNT);

        // Advance time to next year
        vm.warp(block.timestamp + 366 days);

        // Execute another proposal in Year 2
        vm.prank(governance);
        controller.createProposal(MINT_AMOUNT, recipient, "Prop 2");
        _passAndQueueProposal(2);
        vm.warp(block.timestamp + executionDelay + 1);
        vm.prank(governance);
        controller.executeProposal(2);

        assertEq(andeToken.balanceOf(recipient), MINT_AMOUNT * 2, "Balance should be 2x mint amount after year reset");
    }

    // --- Test Group 7 & 8: Cancellation and Pause ---
    function test_Cancel_GovCanCancel() public givenVotersHaveLocked givenProposalIsActive {
        vm.prank(governance);
        vm.expectEmit(true, false, false, false);
        emit MintController.ProposalCancelled(1);
        controller.cancelProposal(1);

        assertEq(uint(controller.getProposalState(1)), 6, "State should be Cancelled");
    }

    function test_Cancel_CannotVoteOnCancelled() public givenVotersHaveLocked givenProposalIsActive {
        vm.prank(governance);
        controller.cancelProposal(1);

        vm.prank(makeAddr("voter1"));
        vm.expectRevert(MintController.ProposalIsCancelled.selector);
        controller.castVote(1, true);
    }

    function test_Pause_GuardianCanPauseAdminCanUnpause() public {
        vm.prank(guardian);
        controller.pause();
        assertTrue(controller.paused(), "Contract should be paused");

        vm.prank(address(this)); // Test contract is admin
        controller.unpause();
        assertFalse(controller.paused(), "Contract should be unpaused");
    }

    function test_Pause_ActionsBlockedWhenPaused() public {
        vm.prank(guardian);
        controller.pause();

        vm.prank(governance);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.createProposal(MINT_AMOUNT, recipient, "Paused");
    }

    // --- Test Group 9 & 10: Parameter Updates & Upgrades ---
    function test_Admin_CanUpdateGovParams() public {
        uint256 newQuorum = 3000; // 30%
        uint256 newVotingPeriod = 5 days;

        vm.prank(address(this)); // Test contract is admin
        controller.updateGovernanceParameters(newQuorum, newVotingPeriod, controller.executionDelay(), controller.proposalLifetime());

        assertEq(controller.quorumPercentage(), newQuorum);
        assertEq(controller.votingPeriod(), newVotingPeriod);
    }

    function test_Admin_CanUpgradeProxy() public {
        MintController newImplementation = new MintController();
        
        vm.prank(address(this)); // Test contract is admin
        controller.upgradeToAndCall(address(newImplementation), "");

        // Verify new implementation is active by checking a value
        assertEq(controller.hardCap(), HARD_CAP);
    }
}
