// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WAndeVault} from "../src/vaults/WAndeVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WAndeVaultTest
 * @author Gemini
 * @notice Unit tests for the WAndeVault ERC-4626 contract.
 */
contract WAndeVaultTest is Test {
    WAndeVault public vault;
    MockERC20 public andeToken;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_USER_BALANCE = 1_000e18;

    function setUp() public {
        // 1. Deploy the mock underlying asset (ANDEToken)
        andeToken = new MockERC20("Mock ANDE Token", "mANDE", 18);

        // 2. Deploy the WAndeVault, linking it to the mock asset
        vault = new WAndeVault(IERC20(address(andeToken)));

        // 3. Mint some mock ANDEToken to our test user
        andeToken.mint(user, INITIAL_USER_BALANCE);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           TESTS                            */
    /*.•°:°.´+˚.*•´,•°:°.´+˚.*•´,•°:°.´+˚.*•´,•°:°.´+˚.*•´,•°:°.´+˚.*/

    function test_InitialState() public {
        assertEq(address(vault.asset()), address(andeToken), "Asset should be ANDEToken");
        assertEq(vault.decimals(), andeToken.decimals(), "Decimals should match asset");
        assertEq(vault.name(), "Vault ANDE", "Vault name is incorrect");
        assertEq(vault.symbol(), "vaANDE", "Vault symbol is incorrect");
    }

    function test_Deposit() public {
        uint256 depositAmount = 100e18;

        // User needs to approve the vault to spend their tokens
        vm.startPrank(user);
        andeToken.approve(address(vault), depositAmount);

        // User deposits assets into the vault
        uint256 sharesReceived = vault.deposit(depositAmount, user);
        vm.stopPrank();

        // --- Assertions ---
        // 1. Shares received should equal assets deposited (1:1 ratio)
        assertEq(sharesReceived, depositAmount, "Shares received should equal assets deposited");

        // 2. User's asset balance should decrease
        assertEq(andeToken.balanceOf(user), INITIAL_USER_BALANCE - depositAmount, "User asset balance is wrong");

        // 3. User's share balance should increase
        assertEq(vault.balanceOf(user), sharesReceived, "User share balance is wrong");

        // 4. Vault's asset balance should increase
        assertEq(andeToken.balanceOf(address(vault)), depositAmount, "Vault asset balance is wrong");

        // 5. Total supply of shares should increase
        assertEq(vault.totalSupply(), sharesReceived, "Total supply of shares is wrong");
    }

    function test_Withdraw() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 40e18;

        // Initial deposit to have something to withdraw
        vm.startPrank(user);
        andeToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);

        // User withdraws assets from the vault
        uint256 sharesBurned = vault.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        // --- Assertions ---
        // 1. Shares burned should equal assets withdrawn (1:1 ratio)
        assertEq(sharesBurned, withdrawAmount, "Shares burned should equal assets withdrawn");

        // 2. User's asset balance should be correctly updated
        assertEq(
            andeToken.balanceOf(user),
            INITIAL_USER_BALANCE - depositAmount + withdrawAmount,
            "User asset balance is wrong"
        );

        // 3. User's share balance should decrease
        assertEq(vault.balanceOf(user), depositAmount - sharesBurned, "User share balance is wrong");

        // 4. Vault's asset balance should decrease
        assertEq(andeToken.balanceOf(address(vault)), depositAmount - withdrawAmount, "Vault asset balance is wrong");
    }

    function test_Fail_DepositWithoutApproval() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(user);
        // We expect this to revert because the user has not approved the vault
        vm.expectRevert();
        vault.deposit(depositAmount, user);
        vm.stopPrank();
    }
}
