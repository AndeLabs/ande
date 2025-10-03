// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MintController} from "../../src/MintController.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {VeANDE} from "../../src/VeANDE.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";

contract MintControllerTest is Test {
    MintController public controller;
    ANDEToken public andeToken;
    VeANDE public veANDE;

    address public admin = makeAddr("admin");
    address public governance = makeAddr("governance");
    address public guardian = makeAddr("guardian");
    address public recipient = makeAddr("recipient");
    address public maliciousUser = makeAddr("maliciousUser");

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
        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, address(this), address(this)))));
        veANDE = VeANDE(address(new ERC1967Proxy(address(new VeANDE()), abi.encodeWithSelector(VeANDE.initialize.selector, address(this), address(andeToken)))));
        controller = MintController(address(new ERC1967Proxy(address(new MintController()), abi.encodeWithSelector(MintController.initialize.selector, address(this), governance, guardian, address(andeToken), address(veANDE), HARD_CAP, ANNUAL_LIMIT))));
        andeToken.grantRole(andeToken.MINTER_ROLE(), address(controller));
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
}
