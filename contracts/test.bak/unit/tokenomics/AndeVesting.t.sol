// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {AndeVesting} from "../../../src/tokenomics/AndeVesting.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";

contract AndeVestingTest is Test {
    AndeVesting public vesting;
    MockERC20 public andeToken;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public teamMember = address(0x4);

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant TGE_TIMESTAMP = 1700000000;

    function setUp() public {
        vm.startPrank(owner);

        andeToken = new MockERC20("ANDE Token", "ANDE", 18);
        andeToken.mint(owner, INITIAL_SUPPLY);

        AndeVesting implementation = new AndeVesting();
        bytes memory initData =
            abi.encodeWithSelector(AndeVesting.initialize.selector, address(andeToken), owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        vesting = AndeVesting(address(proxy));

        andeToken.approve(address(vesting), INITIAL_SUPPLY);

        vm.warp(TGE_TIMESTAMP);
        vesting.setTGE(TGE_TIMESTAMP);

        vm.stopPrank();
    }

    function testInitialization() public view {
        assertEq(address(vesting.andeToken()), address(andeToken));
        assertEq(vesting.tgeTimestamp(), TGE_TIMESTAMP);
        assertTrue(vesting.hasRole(vesting.DEFAULT_ADMIN_ROLE(), owner));
    }

    function testSetTGE() public {
        AndeVesting newVesting;
        vm.startPrank(owner);

        AndeVesting implementation = new AndeVesting();
        bytes memory initData =
            abi.encodeWithSelector(AndeVesting.initialize.selector, address(andeToken), owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        newVesting = AndeVesting(address(proxy));

        uint256 timestamp = block.timestamp + 100 days;
        newVesting.setTGE(timestamp);

        assertEq(newVesting.tgeTimestamp(), timestamp);
        vm.stopPrank();
    }

    function test_RevertWhen_SetTGETwice() public {
        vm.expectRevert(AndeVesting.TGEAlreadySet.selector);
        vm.prank(owner);
        vesting.setTGE(TGE_TIMESTAMP + 1);
    }

    function testCreateTeamVestingSchedule() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.prank(owner);
        uint256 scheduleId =
            vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);

        assertEq(scheduleId, 0);

        AndeVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(teamMember, 0);
        assertEq(schedule.totalAmount, amount);
        assertEq(uint256(schedule.category), uint256(AndeVesting.AllocationCategory.TEAM));
        assertEq(schedule.cliffDuration, vesting.TEAM_CLIFF());
        assertEq(schedule.vestingDuration, vesting.TEAM_VESTING());
    }

    function testCreateCommunityVesting() public {
        uint256 amount = 1_000_000 * 1e18;

        vm.prank(owner);
        vesting.createVestingSchedule(alice, amount, AndeVesting.AllocationCategory.COMMUNITY);

        AndeVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(alice, 0);
        assertEq(schedule.cliffDuration, 0);
        assertEq(schedule.vestingDuration, 1460 days);
    }

    function test_RevertWhen_AllocationExceeded() public {
        uint256 overAllocation = vesting.TEAM_ALLOCATION() + 1;

        vm.expectRevert(AndeVesting.AllocationExceeded.selector);
        vm.prank(owner);
        vesting.createVestingSchedule(alice, overAllocation, AndeVesting.AllocationCategory.TEAM);
    }

    function testClaimBeforeCliff() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 180 days);

        vm.expectRevert(AndeVesting.NothingToClaim.selector);
        vm.prank(teamMember);
        vesting.claim(0);
    }

    function testClaimAfterCliff() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 365 days + 100 days);

        uint256 balanceBefore = andeToken.balanceOf(teamMember);

        vm.prank(teamMember);
        vesting.claim(0);

        uint256 balanceAfter = andeToken.balanceOf(teamMember);
        assertGt(balanceAfter, balanceBefore);
    }

    function testClaimFullyVested() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + vesting.TEAM_VESTING() + 1);

        vm.prank(teamMember);
        vesting.claim(0);

        assertEq(andeToken.balanceOf(teamMember), amount);
    }

    function testClaimMultipleTimes() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 365 days + 100 days);
        vm.prank(teamMember);
        vesting.claim(0);
        uint256 firstClaim = andeToken.balanceOf(teamMember);

        vm.warp(TGE_TIMESTAMP + 365 days + 200 days);
        vm.prank(teamMember);
        vesting.claim(0);
        uint256 secondClaim = andeToken.balanceOf(teamMember);

        assertGt(secondClaim, firstClaim);
    }

    function testClaimAll() public {
        uint256 amount1 = 5_000_000 * 1e18;
        uint256 amount2 = 3_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount1 + amount2);
        vesting.createVestingSchedule(alice, amount1, AndeVesting.AllocationCategory.COMMUNITY);
        vesting.createVestingSchedule(alice, amount2, AndeVesting.AllocationCategory.COMMUNITY);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 200 days);

        vm.prank(alice);
        vesting.claimAll();

        assertGt(andeToken.balanceOf(alice), 0);
    }

    function testBatchVestingSchedules() public {
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = alice;
        beneficiaries[1] = bob;
        beneficiaries[2] = teamMember;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000_000 * 1e18;
        amounts[1] = 2_000_000 * 1e18;
        amounts[2] = 3_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), 6_000_000 * 1e18);
        vesting.createBatchVestingSchedules(
            beneficiaries, amounts, AndeVesting.AllocationCategory.COMMUNITY
        );
        vm.stopPrank();

        assertEq(vesting.getVestingScheduleCount(alice), 1);
        assertEq(vesting.getVestingScheduleCount(bob), 1);
        assertEq(vesting.getVestingScheduleCount(teamMember), 1);
    }

    function testRevokeVestingSchedule() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 365 days + 100 days);

        vm.prank(owner);
        vesting.revokeVestingSchedule(teamMember, 0);

        AndeVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(teamMember, 0);
        assertTrue(schedule.revoked);
    }

    function testGetClaimableAmount() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 364 days);
        uint256 claimable1 = vesting.getClaimableAmount(teamMember, 0);
        assertEq(claimable1, 0);

        vm.warp(TGE_TIMESTAMP + 365 days + 100 days);
        uint256 claimable2 = vesting.getClaimableAmount(teamMember, 0);
        assertGt(claimable2, 0);
    }

    function testGetAllClaimableAmount() public {
        uint256 amount1 = 5_000_000 * 1e18;
        uint256 amount2 = 3_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount1 + amount2);
        vesting.createVestingSchedule(alice, amount1, AndeVesting.AllocationCategory.COMMUNITY);
        vesting.createVestingSchedule(alice, amount2, AndeVesting.AllocationCategory.COMMUNITY);
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 200 days);

        uint256 totalClaimable = vesting.getAllClaimableAmount(alice);
        assertGt(totalClaimable, 0);
    }

    function testGetAllocationStatus() public {
        uint256 amount = 50_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(teamMember, amount, AndeVesting.AllocationCategory.TEAM);
        vm.stopPrank();

        (uint256 maxAllocation, uint256 allocated, uint256 claimed, uint256 available) =
            vesting.getAllocationStatus(AndeVesting.AllocationCategory.TEAM);

        assertEq(maxAllocation, vesting.TEAM_ALLOCATION());
        assertEq(allocated, amount);
        assertEq(claimed, 0);
        assertEq(available, maxAllocation - amount);
    }

    function testSeedInvestorVesting() public {
        uint256 amount = 10_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(
            alice, amount, AndeVesting.AllocationCategory.SEED_INVESTORS
        );
        vm.stopPrank();

        AndeVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(alice, 0);
        assertEq(schedule.cliffDuration, vesting.SEED_CLIFF());
        assertEq(schedule.vestingDuration, vesting.SEED_VESTING());
    }

    function testPrivateInvestorVesting() public {
        uint256 amount = 5_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(
            bob, amount, AndeVesting.AllocationCategory.PRIVATE_INVESTORS
        );
        vm.stopPrank();

        AndeVesting.VestingSchedule memory schedule = vesting.getVestingSchedule(bob, 0);
        assertEq(schedule.cliffDuration, vesting.PRIVATE_CLIFF());
        assertEq(schedule.vestingDuration, vesting.PRIVATE_VESTING());
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);
        vesting.pause();
        assertTrue(vesting.paused());

        vesting.unpause();
        assertFalse(vesting.paused());
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimWhenPaused() public {
        uint256 amount = 1_000_000 * 1e18;

        vm.startPrank(owner);
        andeToken.transfer(address(vesting), amount);
        vesting.createVestingSchedule(alice, amount, AndeVesting.AllocationCategory.COMMUNITY);
        vesting.pause();
        vm.stopPrank();

        vm.warp(TGE_TIMESTAMP + 200 days);

        vm.expectRevert();
        vm.prank(alice);
        vesting.claim(0);
    }
}
