// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingVault} from "../src/staking/StakingVault.sol";
import {WAndeVault} from "../src/vaults/WAndeVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingVaultTest is Test {
    // Contracts
    StakingVault public stakingVault;
    WAndeVault public wAndeVault;
    MockERC20 public andeToken;

    // Test configuration
    address public user = makeAddr("user");
    uint256 public constant UNBONDING_PERIOD = 7 days;
    uint256 public constant INITIAL_ANDE_BALANCE = 1_000e18;

    function setUp() public {
        // 1. Deploy underlying asset (ANDE)
        andeToken = new MockERC20("Mock ANDE Token", "mANDE", 18);
        andeToken.mint(user, INITIAL_ANDE_BALANCE);

        // 2. Deploy the wrapping vault (W-ANDE)
        wAndeVault = new WAndeVault(IERC20(address(andeToken)));

        // 3. Deploy the staking vault
        stakingVault = new StakingVault(IERC20(address(wAndeVault)), UNBONDING_PERIOD);

        // 4. Pre-condition: User wraps some ANDE into vaANDE to be used in tests
        vm.startPrank(user);
        andeToken.approve(address(wAndeVault), INITIAL_ANDE_BALANCE);
        wAndeVault.deposit(INITIAL_ANDE_BALANCE, user);
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertEq(address(stakingVault.asset()), address(wAndeVault), "Asset should be WAndeVault");
        assertEq(stakingVault.unbondingPeriod(), UNBONDING_PERIOD, "Unbonding period is wrong");
        assertEq(stakingVault.name(), "Staked ANDE", "Staking token name is wrong");
        assertEq(stakingVault.symbol(), "stANDE", "Staking token symbol is wrong");
    }

    function test_DepositToStaking() public {
        uint256 stakeAmount = 100e18;

        vm.startPrank(user);
        // Approve the staking vault to spend user's vaANDE
        wAndeVault.approve(address(stakingVault), stakeAmount);

        // Deposit vaANDE into the staking vault
        stakingVault.deposit(stakeAmount, user);
        vm.stopPrank();

        // --- Assertions ---
        // User's vaANDE balance should decrease
        assertEq(wAndeVault.balanceOf(user), INITIAL_ANDE_BALANCE - stakeAmount);
        // User should receive stANDE shares
        assertEq(stakingVault.balanceOf(user), stakeAmount);
        // Staking vault's vaANDE balance should increase
        assertEq(wAndeVault.balanceOf(address(stakingVault)), stakeAmount);
    }

    function test_Full_RequestAndClaimWithdrawal_Flow() public {
        uint256 stakeAmount = 500e18;
        uint256 withdrawShares = 200e18;

        // --- 1. Arrange: User stakes some vaANDE ---
        vm.startPrank(user);
        wAndeVault.approve(address(stakingVault), stakeAmount);
        stakingVault.deposit(stakeAmount, user);
        assertEq(stakingVault.balanceOf(user), stakeAmount);

        // --- 2. Act: Request withdrawal ---
        uint256 requestId = stakingVault.requestWithdrawal(withdrawShares, user);
        vm.stopPrank();

        // --- 3. Assert: Post-request state ---
        assertEq(requestId, 1, "Request ID should be 1");
        // User's stANDE shares are burned immediately
        assertEq(stakingVault.balanceOf(user), stakeAmount - withdrawShares, "stANDE should be burned");
        // Check request struct was created correctly
        (address owner, address receiver, uint256 assets, uint256 claimableAt) = stakingVault.withdrawalRequests(requestId);
        assertEq(owner, user);
        assertEq(receiver, user);
        assertEq(assets, withdrawShares); // 1:1 asset to shares
        assertEq(claimableAt, block.timestamp + UNBONDING_PERIOD);

        // --- 4. Act & Assert: Fail to claim early ---
        vm.prank(user);
        vm.expectRevert("Unbonding period has not passed");
        stakingVault.claimWithdrawal(requestId);

        // --- 5. Act: Wait for unbonding period to pass ---
        vm.warp(block.timestamp + UNBONDING_PERIOD + 1);

        // --- 6. Act & Assert: Claim successfully ---
        uint256 userVaAndeBalanceBeforeClaim = wAndeVault.balanceOf(user);
        vm.prank(user);
        stakingVault.claimWithdrawal(requestId);

        // User's vaANDE balance should be restored
        assertEq(wAndeVault.balanceOf(user), userVaAndeBalanceBeforeClaim + withdrawShares);
        // Request should be deleted
        (owner, , , ) = stakingVault.withdrawalRequests(requestId);
        assertEq(owner, address(0), "Request should be deleted");
    }
}
