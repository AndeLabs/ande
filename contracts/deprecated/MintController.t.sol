// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MintController} from "../../src/MintController.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {VeANDE} from "../../src/VeANDE.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MintControllerTest is Test {
    MintController public controller;
    ANDEToken public andeToken;
    VeANDE public veANDE;

    address public admin = makeAddr("admin");
    address public governance = makeAddr("governance");
    address public guardian = makeAddr("guardian");
    address public recipient = makeAddr("recipient");
    address public maliciousUser = makeAddr("maliciousUser");
    address public user = makeAddr("user");

    uint256 public constant HARD_CAP = 1_500_000_000 * 1e18;
    uint256 public constant ANNUAL_LIMIT = 50_000_000 * 1e18;
    uint256 public constant MINT_AMOUNT = 5_000_000 * 1e18;

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    modifier givenVotersHaveLocked() {
        address[] memory voters = _getVoters();
        uint256 lockAmount = 100_000 * 1e18;
        uint256 unlockTime = block.timestamp + 4 * 365 days;

        for (uint i = 0; i < voters.length; i++) {
            address voter = voters[i];
            // Mint as admin (who has MINTER_ROLE)
            vm.prank(admin);
            andeToken.mint(voter, lockAmount);

            vm.startPrank(voter);
            andeToken.approve(address(veANDE), lockAmount);
            veANDE.createLock(lockAmount, unlockTime);
            vm.stopPrank();
        }
        vm.roll(block.number + 1);
        _;
    }

    modifier givenProposalIsActive() {
        vm.prank(governance);
        controller.createProposal(MINT_AMOUNT, recipient, "Test proposal");
        _;
    }

    function setUp() public {
        // Deploy ANDEToken implementation
        ANDEToken andeImpl = new ANDEToken();

        // Deploy proxy and initialize
        ERC1967Proxy andeProxy = new ERC1967Proxy(
            address(andeImpl),
            abi.encodeWithSelector(ANDEToken.initialize.selector, admin, admin)
        );
        andeToken = ANDEToken(address(andeProxy));

        // Deploy VeANDE implementation
        VeANDE veImpl = new VeANDE();

        // Deploy proxy and initialize
        ERC1967Proxy veProxy = new ERC1967Proxy(
            address(veImpl),
            abi.encodeWithSelector(VeANDE.initialize.selector, admin, address(andeToken))
        );
        veANDE = VeANDE(address(veProxy));

        // Deploy MintController implementation
        MintController controllerImpl = new MintController();

        // Deploy proxy and initialize
        ERC1967Proxy controllerProxy = new ERC1967Proxy(
            address(controllerImpl),
            abi.encodeWithSelector(
                MintController.initialize.selector,
                admin,
                governance,
                guardian,
                address(andeToken),
                address(veANDE),
                HARD_CAP,
                ANNUAL_LIMIT
            )
        );
        controller = MintController(address(controllerProxy));

        // Grant MINTER_ROLE to controller so it can mint
        vm.startPrank(admin);
        andeToken.grantRole(andeToken.MINTER_ROLE(), address(controller));
        vm.stopPrank();
    }

    function test_Deployment_InitializesCorrectly() public view {
        assertEq(address(controller.andeToken()), address(andeToken));
        assertEq(address(controller.veANDE()), address(veANDE));
        assertEq(controller.hardCap(), HARD_CAP);
        assertEq(controller.annualMintLimit(), ANNUAL_LIMIT);
    }

    function test_Proposal_CanCreateProposal() public givenVotersHaveLocked {
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(MINT_AMOUNT, recipient, "Test");
        assertEq(proposalId, 1);
    }

    function test_Voting_CanCastVote() public givenVotersHaveLocked givenProposalIsActive {
        address voter = makeAddr("voter1");
        (uint256 snapshotBlock, ,,) = controller.getProposalTimestamps(1);
        uint256 votePower = veANDE.getPastVotes(voter, snapshotBlock);
        assertTrue(votePower > 0);

        vm.prank(voter);
        controller.castVote(1, true);
        assertTrue(controller.hasVoted(1, voter));
    }

    function test_State_Transitions() public givenVotersHaveLocked givenProposalIsActive {
        uint256 proposalId = 1;
        address[] memory voters = _getVoters();
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(proposalId, true);
        }

        uint256 votingPeriod = controller.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        assertEq(uint(controller.getProposalState(proposalId)), 3); // Succeeded

        controller.queueProposal(proposalId);
        assertEq(uint(controller.getProposalState(proposalId)), 4); // Queued
    }

    function _getVoters() internal returns (address[] memory) {
        address[] memory voters = new address[](4);
        voters[0] = makeAddr("voter1");
        voters[1] = makeAddr("voter2");
        voters[2] = makeAddr("voter3");
        voters[3] = makeAddr("voter4");
        return voters;
    }

    // =============================================================
    // PROPOSAL CREATION - FAILURE TESTS
    // =============================================================

    function test_Fail_CreateProposal_NotGovernance() public {
        vm.prank(maliciousUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                maliciousUser,
                GOVERNANCE_ROLE
            )
        );
        controller.createProposal(MINT_AMOUNT, recipient, "Malicious");
    }

    function test_Fail_CreateProposal_WhenPaused() public {
        vm.prank(guardian);
        controller.pause();

        vm.prank(governance);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        controller.createProposal(MINT_AMOUNT, recipient, "Paused");
    }

    function test_Fail_CreateProposal_ZeroAmount() public {
        vm.prank(governance);
        vm.expectRevert(MintController.ZeroAmount.selector);
        controller.createProposal(0, recipient, "Zero amount");
    }

    function test_Fail_CreateProposal_AmountTooLow() public {
        uint256 minAmount = controller.minProposalAmount();
        vm.prank(governance);
        vm.expectRevert(MintController.BelowMinProposalAmount.selector);
        controller.createProposal(minAmount - 1, recipient, "Too low");
    }

    function test_Fail_CreateProposal_AmountTooHigh() public {
        uint256 maxAmount = controller.maxProposalAmount();
        vm.prank(governance);
        vm.expectRevert(MintController.ExceedsMaxProposalAmount.selector);
        controller.createProposal(maxAmount + 1, recipient, "Too high");
    }

    // =============================================================
    // VOTING - FAILURE TESTS
    // =============================================================

    function test_Fail_CastVote_ProposalNotActive() public {
        vm.prank(makeAddr("voter1"));
        vm.expectRevert(MintController.ProposalNotFound.selector);
        controller.castVote(99, true); // Non-existent proposal
    }

    function test_Fail_CastVote_AlreadyVoted() public givenVotersHaveLocked givenProposalIsActive {
        address voter = makeAddr("voter1");
        vm.prank(voter);
        controller.castVote(1, true);

        // Try to vote again
        vm.prank(voter);
        vm.expectRevert(MintController.AlreadyVoted.selector);
        controller.castVote(1, false);
    }

    function test_Fail_CastVote_NoVotingPower() public givenVotersHaveLocked givenProposalIsActive {
        // maliciousUser has no veANDE
        vm.prank(maliciousUser);
        vm.expectRevert(MintController.NoVotingPower.selector);
        controller.castVote(1, true);
    }

    function test_Fail_CastVote_AfterDeadline() public givenVotersHaveLocked givenProposalIsActive {
        uint256 votingPeriod = controller.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);

        address voter = makeAddr("voter1");
        vm.prank(voter);
        vm.expectRevert(MintController.VotingPeriodEnded.selector);
        controller.castVote(1, true);
    }

    // =============================================================
    // QUEUE & EXECUTION - FAILURE TESTS
    // =============================================================

    function test_Fail_Queue_ProposalNotSucceeded() public givenVotersHaveLocked givenProposalIsActive {
        // Proposal is active, but not yet succeeded. Let's make it fail.
        vm.warp(block.timestamp + controller.votingPeriod() + 1);
        // With no votes, state is Defeated
        vm.expectRevert(MintController.ProposalNotSucceeded.selector);
        controller.queueProposal(1);
    }

    function test_Fail_Queue_VotingPeriodNotEnded() public givenVotersHaveLocked givenProposalIsActive {
        // Get enough votes to succeed
        address[] memory voters = _getVoters();
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(1, true);
        }

        // Try to queue before voting period ends, state is still Active, not Succeeded
        vm.expectRevert(MintController.ProposalNotSucceeded.selector);
        controller.queueProposal(1);
    }

    function test_Fail_Execute_ProposalNotQueued() public givenVotersHaveLocked givenProposalIsActive {
        // Succeed the proposal
        address[] memory voters = _getVoters();
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(1, true);
        }
        vm.warp(block.timestamp + controller.votingPeriod() + 1);

        // Try to execute without queueing
        vm.prank(governance);
        vm.expectRevert(MintController.ProposalNotSucceeded.selector); // State is Succeeded, not Queued
        controller.executeProposal(1);
    }

    function test_Fail_Execute_TimelockNotMet() public givenVotersHaveLocked givenProposalIsActive {
        // Succeed and queue the proposal
        _succeedAndQueueProposal(1);

        // Try to execute immediately
        vm.prank(governance);
        vm.expectRevert(MintController.ProposalTimelockNotMet.selector);
        controller.executeProposal(1);
    }

    function test_Fail_Execute_ProposalExpired() public givenVotersHaveLocked givenProposalIsActive {
        // Succeed and queue the proposal
        _succeedAndQueueProposal(1);

        // Warp time past the proposal's lifetime
        vm.warp(block.timestamp + controller.proposalLifetime() + 1);

        vm.prank(governance);
        // The state becomes Expired, so the first check in executeProposal fails
        vm.expectRevert(MintController.ProposalNotSucceeded.selector);
        controller.executeProposal(1);
    }

    function test_Fail_Execute_AlreadyExecuted() public givenVotersHaveLocked givenProposalIsActive {
        // Succeed, queue, and execute the proposal
        _succeedAndQueueProposal(1);
        vm.warp(block.timestamp + controller.executionDelay() + 1);
        vm.prank(governance);
        controller.executeProposal(1);

        // Try to execute again
        vm.prank(governance);
        vm.expectRevert(MintController.ProposalNotSucceeded.selector); // State is Executed, not Queued
        controller.executeProposal(1);
    }

    // =============================================================
    // HELPER FUNCTIONS
    // =============================================================

    function _succeedAndQueueProposal(uint256 proposalId) internal {
        address[] memory voters = _getVoters();
        for (uint i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            controller.castVote(proposalId, true);
        }
        vm.warp(block.timestamp + controller.votingPeriod() + 1);
        controller.queueProposal(proposalId);
    }

    // =============================================================
    // ANNUAL LIMIT ENFORCEMENT TESTS
    // =============================================================

    function test_Execute_RespectAnnualLimit() public givenVotersHaveLocked {
        // Create proposal within limits (maxProposalAmount = annualLimit / 10)
        uint256 amount = ANNUAL_LIMIT / 20; // 5% of annual limit, well within 10% max

        vm.prank(governance);
        uint256 proposalId = controller.createProposal(amount, recipient, "Within limit");

        _succeedAndQueueProposal(proposalId);
        vm.warp(block.timestamp + controller.executionDelay() + 1);

        vm.prank(governance);
        controller.executeProposal(proposalId);

        assertEq(andeToken.balanceOf(recipient), amount);
    }

    function test_Fail_Execute_ExceedsAnnualLimit() public givenVotersHaveLocked {
        // Strategy: Create a valid proposal, use emergency mint to consume annual limit, then try to execute

        // Create a valid proposal for 5% of annual limit
        uint256 proposalAmount = (ANNUAL_LIMIT * 5) / 100;
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(proposalAmount, recipient, "Test");
        _succeedAndQueueProposal(proposalId);
        vm.warp(block.timestamp + controller.executionDelay() + 1);

        // Now use emergency mint to consume most of the annual limit
        // This happens AFTER proposal creation but BEFORE execution
        vm.prank(guardian);
        controller.pause();

        uint256 emergencyAmount = (ANNUAL_LIMIT * 96) / 100; // Use 96% via emergency
        vm.prank(admin);
        controller.emergencyMint(user, emergencyAmount, "Emergency");

        // Admin unpauses (only admin can unpause)
        vm.prank(admin);
        controller.unpause();

        // Now trying to execute the 5% proposal should fail (96% + 5% = 101% > 100%)
        vm.prank(governance);
        vm.expectRevert(MintController.ExceedsAnnualLimit.selector);
        controller.executeProposal(proposalId);
    }

    function test_AnnualLimit_ResetsNextYear() public givenVotersHaveLocked {
        // Use max proposal amount per proposal (10% default)
        uint256 maxPerProposal = ANNUAL_LIMIT / 10;

        // Year 1: Create and execute one proposal
        vm.prank(governance);
        uint256 proposalId1 = controller.createProposal(maxPerProposal, recipient, "Year 1");
        _succeedAndQueueProposal(proposalId1);
        vm.warp(block.timestamp + controller.executionDelay() + 1);
        vm.prank(governance);
        controller.executeProposal(proposalId1);

        // Warp to next year (365 days + 1 second)
        vm.warp(block.timestamp + 365 days + 1);

        // Should be able to mint again
        vm.prank(governance);
        uint256 proposalId2 = controller.createProposal(maxPerProposal, recipient, "Year 2");
        _succeedAndQueueProposal(proposalId2);
        vm.warp(block.timestamp + controller.executionDelay() + 1);
        vm.prank(governance);
        controller.executeProposal(proposalId2);

        assertEq(andeToken.balanceOf(recipient), maxPerProposal * 2);
    }

    // =============================================================
    // HARD CAP ENFORCEMENT TESTS
    // =============================================================

    function test_Fail_Execute_ExceedsHardCap() public givenVotersHaveLocked {
        // Strategy: Create a valid proposal, then mint tokens to push near hard cap, then try to execute

        // First increase annual limit to allow large emergency mint (admin can do this anytime)
        vm.prank(admin);
        controller.updateMintLimits(HARD_CAP, HARD_CAP / 2, 1000e18); // Set annual limit to 750M

        // Create a valid proposal for 5M tokens
        uint256 proposalAmount = 5_000_000e18;
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(proposalAmount, recipient, "Test");
        _succeedAndQueueProposal(proposalId);
        vm.warp(block.timestamp + controller.executionDelay() + 1);

        // Pause for emergency mint
        vm.prank(guardian);
        controller.pause();

        // Emergency mint to leave only 3M capacity (HARD_CAP - 3M)
        uint256 emergencyAmount = HARD_CAP - 3_000_000e18;
        vm.prank(admin);
        controller.emergencyMint(user, emergencyAmount, "Emergency");

        // Admin unpauses (only admin can unpause)
        vm.prank(admin);
        controller.unpause();

        // Now executing the 5M proposal should fail (only 3M capacity left, need 5M)
        vm.prank(governance);
        vm.expectRevert(MintController.ExceedsHardCap.selector);
        controller.executeProposal(proposalId);
    }

    function test_GetRemainingCapacity_Accurate() public {
        uint256 initialCapacity = controller.getRemainingHardCapCapacity();
        assertEq(initialCapacity, HARD_CAP);

        // Mint some tokens (as admin who has MINTER_ROLE)
        uint256 mintedAmount = 100_000e18;
        vm.prank(admin);
        andeToken.mint(recipient, mintedAmount);

        uint256 newCapacity = controller.getRemainingHardCapCapacity();
        assertEq(newCapacity, HARD_CAP - mintedAmount);
    }

    function test_GetRemainingAnnualCapacity_Accurate() public givenVotersHaveLocked {
        uint256 initialCapacity = controller.getRemainingAnnualCapacity();
        assertEq(initialCapacity, ANNUAL_LIMIT);

        // Execute a proposal
        uint256 amount = MINT_AMOUNT;
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(amount, recipient, "Test");
        _succeedAndQueueProposal(proposalId);
        vm.warp(block.timestamp + controller.executionDelay() + 1);
        vm.prank(governance);
        controller.executeProposal(proposalId);

        uint256 newCapacity = controller.getRemainingAnnualCapacity();
        assertEq(newCapacity, ANNUAL_LIMIT - amount);
    }

    // =============================================================
    // EMERGENCY FUNCTIONS TESTS
    // =============================================================

    function test_EmergencyMint_OnlyAdminWhenPaused() public {
        // Pause the contract
        vm.prank(guardian);
        controller.pause();

        uint256 emergencyAmount = 1000e18;

        vm.prank(admin);
        controller.emergencyMint(recipient, emergencyAmount, "Emergency funding");

        assertEq(andeToken.balanceOf(recipient), emergencyAmount);
    }

    function test_Fail_EmergencyMint_WhenNotPaused() public {
        vm.prank(admin);
        vm.expectRevert();
        controller.emergencyMint(recipient, 1000e18, "Should fail");
    }

    function test_Fail_EmergencyMint_ZeroAddress() public {
        vm.prank(guardian);
        controller.pause();

        vm.prank(admin);
        vm.expectRevert(MintController.InvalidRecipient.selector);
        controller.emergencyMint(address(0), 1000e18, "Zero address");
    }

    function test_Fail_EmergencyMint_ZeroAmount() public {
        vm.prank(guardian);
        controller.pause();

        vm.prank(admin);
        vm.expectRevert(MintController.ZeroAmount.selector);
        controller.emergencyMint(recipient, 0, "Zero amount");
    }

    function test_Fail_EmergencyMint_OnlyAdmin() public {
        vm.prank(guardian);
        controller.pause();

        vm.prank(user);
        vm.expectRevert();
        controller.emergencyMint(recipient, 1000e18, "Unauthorized");
    }

    // =============================================================
    // CANCEL PROPOSAL TESTS
    // =============================================================

    function test_Cancel_GovernanceCanCancel() public givenVotersHaveLocked givenProposalIsActive {
        vm.prank(governance);
        controller.cancelProposal(1);

        assertEq(uint(controller.getProposalState(1)), uint(MintController.ProposalState.Cancelled));
    }

    function test_Cancel_GuardianCanCancel() public givenVotersHaveLocked givenProposalIsActive {
        vm.prank(guardian);
        controller.cancelProposal(1);

        assertEq(uint(controller.getProposalState(1)), uint(MintController.ProposalState.Cancelled));
    }

    function test_Fail_Cancel_UnauthorizedUser() public givenVotersHaveLocked givenProposalIsActive {
        vm.prank(maliciousUser);
        vm.expectRevert(MintController.InvalidParameters.selector);
        controller.cancelProposal(1);
    }

    function test_Fail_Cancel_NonexistentProposal() public {
        vm.prank(governance);
        vm.expectRevert(MintController.ProposalNotFound.selector);
        controller.cancelProposal(999);
    }

    function test_Fail_Execute_CancelledProposal() public givenVotersHaveLocked givenProposalIsActive {
        // Cancel the proposal
        vm.prank(governance);
        controller.cancelProposal(1);

        // Try to queue it
        vm.warp(block.timestamp + controller.votingPeriod() + 1);
        vm.expectRevert(MintController.ProposalNotSucceeded.selector);
        controller.queueProposal(1);
    }

    // =============================================================
    // GOVERNANCE PARAMETER UPDATES
    // =============================================================

    function test_UpdateGovernanceParameters_Admin() public {
        uint256 newQuorum = 2000; // 20%
        uint256 newVotingPeriod = 10 days;
        uint256 newExecutionDelay = 3 days;
        uint256 newProposalLifetime = 30 days;

        vm.prank(admin);
        controller.updateGovernanceParameters(
            newQuorum,
            newVotingPeriod,
            newExecutionDelay,
            newProposalLifetime
        );

        assertEq(controller.quorumPercentage(), newQuorum);
        assertEq(controller.votingPeriod(), newVotingPeriod);
        assertEq(controller.executionDelay(), newExecutionDelay);
        assertEq(controller.proposalLifetime(), newProposalLifetime);
    }

    function test_Fail_UpdateGovernanceParameters_InvalidQuorum() public {
        vm.prank(admin);
        vm.expectRevert(MintController.InvalidParameters.selector);
        controller.updateGovernanceParameters(
            10001, // > 100%
            7 days,
            2 days,
            14 days
        );
    }

    function test_UpdateMintLimits_Admin() public {
        uint256 newAnnualLimit = 100_000_000e18;
        uint256 newMax = 10_000_000e18;
        uint256 newMin = 100_000e18;

        vm.prank(admin);
        controller.updateMintLimits(newAnnualLimit, newMax, newMin);

        assertEq(controller.annualMintLimit(), newAnnualLimit);
        assertEq(controller.minProposalAmount(), newMin);
        assertEq(controller.maxProposalAmount(), newMax);
    }

    function test_Fail_UpdateMintLimits_MinGreaterThanMax() public {
        vm.prank(admin);
        vm.expectRevert(MintController.InvalidParameters.selector);
        controller.updateMintLimits(ANNUAL_LIMIT, 100e18, 1000e18); // min > max
    }

    function test_Fail_UpdateMintLimits_MaxGreaterThanAnnual() public {
        vm.prank(admin);
        vm.expectRevert(MintController.InvalidParameters.selector);
        controller.updateMintLimits(1000e18, 10000e18, 100e18); // max > annual
    }

    function test_UpdateHardCap_Admin() public {
        uint256 newCap = 2_000_000_000e18;

        vm.prank(admin);
        controller.updateHardCap(newCap);

        assertEq(controller.hardCap(), newCap);
    }

    function test_Fail_UpdateHardCap_BelowCurrentSupply() public {
        // Mint tokens to increase supply (as admin who has MINTER_ROLE)
        uint256 currentSupply = 1_000_000_000e18; // 1B tokens
        vm.prank(admin);
        andeToken.mint(recipient, currentSupply);

        // Try to set hard cap above current hardCap but below total supply
        // Current hardCap = 1.5B, totalSupply = 1B, trying to set to 1.6B (> 1.5B but < total supply is invalid)
        // Wait, that doesn't make sense. Let me re-think:
        // We need: newCap > hardCap BUT newCap < totalSupply
        // If totalSupply = 1B and hardCap = 1.5B, we can't test this case.
        // We need totalSupply > hardCap first, then try to set newCap between them.

        // Actually, looking at line 651: if (_newHardCap <= andeToken.totalSupply()) revert InvalidHardCap();
        // This means newCap must be GREATER than totalSupply.
        // So we need: newCap > currentHardCap (line 650) AND newCap > totalSupply (line 651)
        // To trigger line 651 error: newCap > currentHardCap BUT newCap <= totalSupply

        // Mint more than current hard cap (1.5B + 100M = 1.6B)
        uint256 aboveHardCap = HARD_CAP + 100_000_000e18;
        vm.prank(address(controller)); // controller has MINTER_ROLE
        andeToken.mint(recipient, aboveHardCap);

        // Try to set new hard cap > current but <= totalSupply
        uint256 newCap = HARD_CAP + 50_000_000e18; // 1.55B (> 1.5B but < 1.6B supply)
        vm.prank(admin);
        vm.expectRevert(MintController.InvalidHardCap.selector);
        controller.updateHardCap(newCap);
    }

    // =============================================================
    // EDGE CASES & FUZZING
    // =============================================================

    function testFuzz_CreateProposal_VariousAmounts(uint256 amount) public givenVotersHaveLocked {
        uint256 minAmount = controller.minProposalAmount();
        uint256 maxAmount = controller.maxProposalAmount();

        amount = bound(amount, minAmount, maxAmount);

        uint256 currentCount = proposalCount();
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(amount, recipient, "Fuzz test");

        assertEq(proposalId, currentCount + 1);
    }

    function test_MultipleProposals_InParallel() public givenVotersHaveLocked {
        // Create 3 proposals
        vm.startPrank(governance);
        uint256 p1 = controller.createProposal(1000e18, recipient, "Proposal 1");
        uint256 p2 = controller.createProposal(2000e18, recipient, "Proposal 2");
        uint256 p3 = controller.createProposal(3000e18, recipient, "Proposal 3");
        vm.stopPrank();

        // All should be active
        assertEq(uint(controller.getProposalState(p1)), uint(MintController.ProposalState.Active));
        assertEq(uint(controller.getProposalState(p2)), uint(MintController.ProposalState.Active));
        assertEq(uint(controller.getProposalState(p3)), uint(MintController.ProposalState.Active));
    }

    function test_ProposalExpiry_AfterLifetime() public givenVotersHaveLocked givenProposalIsActive {
        // Succeed and queue the proposal
        _succeedAndQueueProposal(1);

        // Warp past proposal lifetime
        vm.warp(block.timestamp + controller.proposalLifetime() + 1);

        // Should be expired
        assertEq(uint(controller.getProposalState(1)), uint(MintController.ProposalState.Expired));
    }

    function test_VoteFor_DelegatedVoting() public givenVotersHaveLocked {
        address delegator = makeAddr("delegator");

        // Give delegator some voting power by locking ANDE tokens BEFORE creating proposal
        uint256 lockAmount = 50_000 * 1e18;
        vm.prank(admin);
        andeToken.mint(delegator, lockAmount);

        vm.startPrank(delegator);
        andeToken.approve(address(veANDE), lockAmount);
        veANDE.createLock(lockAmount, block.timestamp + 365 days);
        vm.stopPrank();

        vm.roll(block.number + 1); // Move to next block so voting power is checkpointed

        // NOW create the proposal (snapshot will be block.number - 1, which has delegator's voting power)
        vm.prank(governance);
        uint256 proposalId = controller.createProposal(MINT_AMOUNT, recipient, "Test proposal");

        // castVoteFor requires GOVERNANCE_ROLE
        vm.prank(governance);
        controller.castVoteFor(proposalId, delegator, true);

        assertTrue(controller.hasVoted(proposalId, delegator));
    }

    // Helper to get current proposal count
    function proposalCount() internal view returns (uint256) {
        return controller.proposalCount();
    }
}
