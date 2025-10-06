// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Contracts under test
import {ANDEToken} from "../../src/ANDEToken.sol";
import {StakingVault} from "../../src/staking/StakingVault.sol";
import {AndeGovernor} from "../../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../../src/governance/AndeTimelockController.sol";

// Interfaces
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title GovernanceFlow Integration Test
 * @notice Tests the complete governance flow: Stake → Propose → Vote → Queue → Execute
 * @dev This test validates the new liquid staking governance model with stANDE
 */
contract GovernanceFlowTest is Test {
    // Contracts
    ANDEToken public andeToken;
    StakingVault public stakingVault;
    AndeGovernor public governor;
    AndeTimelockController public timelock;

    // Test actors
    address public admin = makeAddr("admin");
    address public proposer = makeAddr("proposer");
    address public voter1 = makeAddr("voter1");
    address public voter2 = makeAddr("voter2");
    address public voter3 = makeAddr("voter3");

    // Governance parameters
    uint48 public constant VOTING_DELAY = uint48(1 days);
    uint32 public constant VOTING_PERIOD = uint32(1 weeks);
    uint256 public constant PROPOSAL_THRESHOLD = 100_000e18; // 100k stANDE needed to propose
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4% quorum
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant UNBONDING_PERIOD = 7 days;

    // Test constants
    uint256 public constant INITIAL_ANDE_SUPPLY = 1_000_000_000e18; // 1 billion
    uint256 public constant STAKE_AMOUNT_PROPOSER = 150_000e18; // Above threshold
    uint256 public constant STAKE_AMOUNT_VOTER = 50_000e18;

    // Events to test
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
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy ANDEToken
        ANDEToken andeImpl = new ANDEToken();
        bytes memory andeInitData = abi.encodeWithSelector(
            ANDEToken.initialize.selector,
            admin, // defaultAdmin
            admin  // minter (will be changed to MintController later)
        );
        ERC1967Proxy andeProxy = new ERC1967Proxy(address(andeImpl), andeInitData);
        andeToken = ANDEToken(address(andeProxy));

        // 2. Deploy StakingVault (stANDE)
        StakingVault stakingImpl = new StakingVault();
        bytes memory stakingInitData = abi.encodeWithSelector(
            StakingVault.initialize.selector,
            admin,
            address(andeToken),
            UNBONDING_PERIOD
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        stakingVault = StakingVault(address(stakingProxy));

        // 3. Deploy TimelockController
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute

        AndeTimelockController timelockImpl = new AndeTimelockController();
        bytes memory timelockInitData = abi.encodeWithSelector(
            AndeTimelockController.initialize.selector,
            TIMELOCK_DELAY,
            proposers, // Will set governor as proposer after deployment
            executors,
            admin
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(address(timelockImpl), timelockInitData);
        timelock = AndeTimelockController(payable(address(timelockProxy)));

        // 4. Deploy Governor
        AndeGovernor governorImpl = new AndeGovernor();
        bytes memory governorInitData = abi.encodeWithSelector(
            AndeGovernor.initialize.selector,
            IVotes(address(stakingVault)), // stANDE is the voting token
            timelock,
            QUORUM_PERCENTAGE,
            VOTING_PERIOD,
            VOTING_DELAY,
            PROPOSAL_THRESHOLD
        );
        ERC1967Proxy governorProxy = new ERC1967Proxy(address(governorImpl), governorInitData);
        governor = AndeGovernor(payable(address(governorProxy)));

        // 5. Grant timelock roles to governor
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));

        // 6. Mint ANDE to test users
        andeToken.mint(proposer, STAKE_AMOUNT_PROPOSER);
        andeToken.mint(voter1, STAKE_AMOUNT_VOTER);
        andeToken.mint(voter2, STAKE_AMOUNT_VOTER);
        andeToken.mint(voter3, STAKE_AMOUNT_VOTER);

        vm.stopPrank();

        // 7. Users stake their ANDE to get stANDE (voting power)
        _stakeTokens(proposer, STAKE_AMOUNT_PROPOSER);
        _stakeTokens(voter1, STAKE_AMOUNT_VOTER);
        _stakeTokens(voter2, STAKE_AMOUNT_VOTER);
        _stakeTokens(voter3, STAKE_AMOUNT_VOTER);

        // 8. Delegate voting power to self (required for ERC20Votes)
        vm.prank(proposer);
        stakingVault.delegate(proposer);

        vm.prank(voter1);
        stakingVault.delegate(voter1);

        vm.prank(voter2);
        stakingVault.delegate(voter2);

        vm.prank(voter3);
        stakingVault.delegate(voter3);

        // Roll forward to ensure votes are counted
        vm.roll(block.number + 1);
    }

    function _stakeTokens(address user, uint256 amount) internal {
        vm.startPrank(user);
        andeToken.approve(address(stakingVault), amount);
        stakingVault.deposit(amount, user);
        vm.stopPrank();
    }

    /// @notice Test 1: Complete governance flow - Propose → Vote → Queue → Execute
    function test_CompleteGovernanceFlow() public {
        // ============ STEP 1: CREATE PROPOSAL ============

        // Create a simple proposal: transfer some ANDE from timelock to a recipient
        address recipient = makeAddr("recipient");
        uint256 transferAmount = 1000e18;

        // First, fund the timelock with some ANDE
        vm.prank(admin);
        andeToken.mint(address(timelock), transferAmount);

        // Prepare proposal data
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            andeToken.transfer.selector,
            recipient,
            transferAmount
        );

        string memory description = "Proposal #1: Transfer 1000 ANDE to recipient";

        // Proposer creates the proposal
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("Proposal created with ID:", proposalId);

        // Verify proposal is in Pending state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // ============ STEP 2: VOTING DELAY ============

        // Fast forward past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // Proposal should now be Active
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));
        console.log("Proposal is now Active");

        // ============ STEP 3: CAST VOTES ============

        // voter1 votes FOR (support = 1)
        vm.prank(voter1);
        governor.castVote(proposalId, 1);
        console.log("voter1 voted FOR");

        // voter2 votes FOR (support = 1)
        vm.prank(voter2);
        governor.castVote(proposalId, 1);
        console.log("voter2 voted FOR");

        // voter3 votes AGAINST (support = 0)
        vm.prank(voter3);
        governor.castVote(proposalId, 0);
        console.log("voter3 voted AGAINST");

        // ============ STEP 4: VOTING PERIOD ENDS ============

        // Fast forward to end of voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Proposal should be Succeeded (more FOR votes than AGAINST)
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
        console.log("Proposal Succeeded");

        // ============ STEP 5: QUEUE PROPOSAL ============

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Proposal should now be Queued
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));
        console.log("Proposal Queued in Timelock");

        // ============ STEP 6: TIMELOCK DELAY ============

        // Fast forward past timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // ============ STEP 7: EXECUTE PROPOSAL ============

        uint256 recipientBalanceBefore = andeToken.balanceOf(recipient);
        assertEq(recipientBalanceBefore, 0);

        governor.execute(targets, values, calldatas, descriptionHash);

        // Proposal should now be Executed
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        console.log("Proposal Executed");

        // ============ STEP 8: VERIFY EXECUTION ============

        uint256 recipientBalanceAfter = andeToken.balanceOf(recipient);
        assertEq(recipientBalanceAfter, transferAmount);
        console.log("Recipient received:", recipientBalanceAfter / 1e18, "ANDE");
    }

    /// @notice Test 2: Proposal fails due to insufficient voting power
    function test_ProposalFailsWithInsufficientThreshold() public {
        address lowStaker = makeAddr("lowStaker");
        uint256 lowStake = 50_000e18; // Below threshold

        vm.prank(admin);
        andeToken.mint(lowStaker, lowStake);

        _stakeTokens(lowStaker, lowStake);

        vm.prank(lowStaker);
        stakingVault.delegate(lowStaker);

        vm.roll(block.number + 1);

        // Attempt to create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(andeToken.transfer.selector, address(0), 1);

        vm.prank(lowStaker);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Should fail");
    }

    /// @notice Test 3: Proposal is defeated when votes against > votes for
    function test_ProposalDefeated() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(andeToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(andeToken.transfer.selector, address(0), 1);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test proposal");

        // Move to active
        vm.roll(block.number + VOTING_DELAY + 1);

        // Proposer votes FOR (150k votes)
        vm.prank(proposer);
        governor.castVote(proposalId, 1);

        // All other voters vote AGAINST (150k votes total)
        vm.prank(voter1);
        governor.castVote(proposalId, 0);

        vm.prank(voter2);
        governor.castVote(proposalId, 0);

        vm.prank(voter3);
        governor.castVote(proposalId, 0);

        // End voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Proposal should be Defeated
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
        console.log("Proposal was Defeated as expected");
    }

    /// @notice Test 4: Verify quorum requirement (4%)
    function test_QuorumRequirement() public {
        // Total staked: 300k stANDE
        // Quorum: 4% = 12k stANDE

        uint256 totalSupply = stakingVault.totalSupply();
        uint256 requiredQuorum = governor.quorum(block.number - 1);

        console.log("Total stANDE supply:", totalSupply / 1e18);
        console.log("Required quorum:", requiredQuorum / 1e18);

        assertEq(requiredQuorum, (totalSupply * QUORUM_PERCENTAGE) / 100);
    }

    /// @notice Test 5: Voting power delegation works correctly
    function test_VotingPowerDelegation() public {
        address delegator = makeAddr("delegator");
        address delegatee = makeAddr("delegatee");

        uint256 delegateAmount = 100_000e18;

        // Mint and stake
        vm.prank(admin);
        andeToken.mint(delegator, delegateAmount);

        _stakeTokens(delegator, delegateAmount);

        // Delegate to delegatee
        vm.prank(delegator);
        stakingVault.delegate(delegatee);

        vm.roll(block.number + 1);

        // Check voting power
        uint256 delegateeVotes = stakingVault.getVotes(delegatee);
        uint256 delegatorVotes = stakingVault.getVotes(delegator);

        assertEq(delegateeVotes, delegateAmount);
        assertEq(delegatorVotes, 0);

        console.log("Delegation successful: delegatee has", delegateeVotes / 1e18, "votes");
    }

    /// @notice Test 6: Staking affects voting power correctly
    function test_StakingAffectsVotingPower() public {
        address newUser = makeAddr("newUser");
        uint256 initialStake = 10_000e18;
        uint256 additionalStake = 5_000e18;

        // Initial stake
        vm.prank(admin);
        andeToken.mint(newUser, initialStake + additionalStake);

        _stakeTokens(newUser, initialStake);

        vm.prank(newUser);
        stakingVault.delegate(newUser);

        vm.roll(block.number + 1);

        uint256 votesAfterFirst = stakingVault.getVotes(newUser);
        assertEq(votesAfterFirst, initialStake);

        // Additional stake
        _stakeTokens(newUser, additionalStake);

        vm.roll(block.number + 1);

        uint256 votesAfterSecond = stakingVault.getVotes(newUser);
        assertEq(votesAfterSecond, initialStake + additionalStake);

        console.log("Voting power increased correctly with additional stake");
    }
}
