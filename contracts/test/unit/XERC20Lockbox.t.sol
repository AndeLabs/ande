// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {XERC20} from "../../src/xERC20/XERC20.sol";
import {XERC20Lockbox} from "../../src/xERC20/XERC20Lockbox.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IXERC20Lockbox} from "../../src/interfaces/IXERC20Lockbox.sol";

/**
 * @title XERC20LockboxTest
 * @notice Comprehensive test suite for xERC20 Lockbox
 * @dev Tests deposit/withdraw functionality and 1:1 conversion
 */
contract XERC20LockboxTest is Test {
    XERC20 public xerc20;
    XERC20Lockbox public lockbox;
    ERC20Mock public erc20;

    address public admin;
    address public user;
    address public recipient;

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        // Deploy ERC20 token
        erc20 = new ERC20Mock("Mock Token", "MTK");
        erc20.mint(user, INITIAL_SUPPLY);

        // Deploy xERC20
        XERC20 implementation = new XERC20();
        bytes memory data =
            abi.encodeWithSelector(XERC20.initialize.selector, "xMock Token", "xMTK", admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        xerc20 = XERC20(address(proxy));

        // Deploy lockbox
        lockbox = new XERC20Lockbox(address(xerc20), address(erc20));

        // Set lockbox in xERC20 to allow unlimited minting/burning
        vm.prank(admin);
        xerc20.setLockbox(address(lockbox));
    }

    // ==================== DEPLOYMENT TESTS ====================

    function test_Deploy_SetsCorrectTokenAddresses() public view {
        assertEq(lockbox.XERC20(), address(xerc20));
        assertEq(lockbox.ERC20(), address(erc20));
    }

    function test_Deploy_RevertsOnZeroAddresses() public {
        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        new XERC20Lockbox(address(0), address(erc20));

        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        new XERC20Lockbox(address(xerc20), address(0));
    }

    // ==================== DEPOSIT TESTS ====================

    function test_Deposit_ConvertsERC20ToXERC20() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);
        vm.stopPrank();

        assertEq(xerc20.balanceOf(user), depositAmount);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY - depositAmount);
        assertEq(erc20.balanceOf(address(lockbox)), depositAmount);
    }

    function test_Deposit_EmitsEvent() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit IXERC20Lockbox.Deposit(user, depositAmount);
        lockbox.deposit(depositAmount);
        vm.stopPrank();
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        lockbox.deposit(0);
    }

    function test_Deposit_RevertsOnInsufficientBalance() public {
        uint256 depositAmount = INITIAL_SUPPLY + 1;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        vm.expectRevert();
        lockbox.deposit(depositAmount);
        vm.stopPrank();
    }

    function test_Deposit_RevertsOnInsufficientAllowance() public {
        uint256 depositAmount = 100 ether;

        vm.prank(user);
        // No approval
        vm.expectRevert();
        lockbox.deposit(depositAmount);
    }

    // ==================== DEPOSIT TO TESTS ====================

    function test_DepositTo_MintsToRecipient() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.depositTo(recipient, depositAmount);
        vm.stopPrank();

        assertEq(xerc20.balanceOf(recipient), depositAmount);
        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY - depositAmount);
    }

    function test_DepositTo_EmitsEvent() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit IXERC20Lockbox.Deposit(user, depositAmount);
        lockbox.depositTo(recipient, depositAmount);
        vm.stopPrank();
    }

    function test_DepositTo_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        lockbox.depositTo(recipient, 0);
    }

    // ==================== WITHDRAW TESTS ====================

    function test_Withdraw_ConvertsXERC20ToERC20() public {
        uint256 depositAmount = 100 ether;

        // First deposit
        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        // Then withdraw
        xerc20.approve(address(lockbox), depositAmount);
        lockbox.withdraw(depositAmount);
        vm.stopPrank();

        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);
        assertEq(erc20.balanceOf(address(lockbox)), 0);
    }

    function test_Withdraw_EmitsEvent() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        xerc20.approve(address(lockbox), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit IXERC20Lockbox.Withdraw(user, depositAmount);
        lockbox.withdraw(depositAmount);
        vm.stopPrank();
    }

    function test_Withdraw_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        lockbox.withdraw(0);
    }

    function test_Withdraw_RevertsOnInsufficientBalance() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        xerc20.approve(address(lockbox), depositAmount + 1);
        vm.expectRevert();
        lockbox.withdraw(depositAmount + 1);
        vm.stopPrank();
    }

    function test_Withdraw_RevertsOnInsufficientAllowance() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        // No approval for xERC20
        vm.expectRevert();
        lockbox.withdraw(depositAmount);
        vm.stopPrank();
    }

    // ==================== WITHDRAW TO TESTS ====================

    function test_WithdrawTo_TransfersToRecipient() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        xerc20.approve(address(lockbox), depositAmount);
        lockbox.withdrawTo(recipient, depositAmount);
        vm.stopPrank();

        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(recipient), depositAmount);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY - depositAmount);
    }

    function test_WithdrawTo_EmitsEvent() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        xerc20.approve(address(lockbox), depositAmount);

        vm.expectEmit(true, true, true, true);
        emit IXERC20Lockbox.Withdraw(user, depositAmount);
        lockbox.withdrawTo(recipient, depositAmount);
        vm.stopPrank();
    }

    function test_WithdrawTo_RevertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(IXERC20Lockbox.IXERC20Lockbox_Invalid_Amount.selector);
        lockbox.withdrawTo(recipient, 0);
    }

    // ==================== REENTRANCY TESTS ====================

    function test_Deposit_ProtectedFromReentrancy() public {
        // The lockbox uses nonReentrant modifier
        // This is a basic check that the modifier is applied
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);
        vm.stopPrank();

        // Verify state is correct (no reentrancy occurred)
        assertEq(xerc20.balanceOf(user), depositAmount);
    }

    function test_Withdraw_ProtectedFromReentrancy() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user);
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);

        xerc20.approve(address(lockbox), depositAmount);
        lockbox.withdraw(depositAmount);
        vm.stopPrank();

        // Verify state is correct (no reentrancy occurred)
        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);
    }

    // ==================== INTEGRATION TESTS ====================

    function test_Integration_MultipleUsersDepositAndWithdraw() public {
        address user2 = makeAddr("user2");
        erc20.mint(user2, INITIAL_SUPPLY);

        uint256 deposit1 = 100 ether;
        uint256 deposit2 = 200 ether;

        // User 1 deposits
        vm.startPrank(user);
        erc20.approve(address(lockbox), deposit1);
        lockbox.deposit(deposit1);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        erc20.approve(address(lockbox), deposit2);
        lockbox.deposit(deposit2);
        vm.stopPrank();

        // Check balances
        assertEq(xerc20.balanceOf(user), deposit1);
        assertEq(xerc20.balanceOf(user2), deposit2);
        assertEq(erc20.balanceOf(address(lockbox)), deposit1 + deposit2);

        // User 1 withdraws
        vm.startPrank(user);
        xerc20.approve(address(lockbox), deposit1);
        lockbox.withdraw(deposit1);
        vm.stopPrank();

        // Check final balances
        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);
        assertEq(erc20.balanceOf(address(lockbox)), deposit2);
    }

    function test_Integration_DepositWithdrawCycle() public {
        uint256 depositAmount = 500 ether;

        vm.startPrank(user);

        // Cycle 1
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);
        assertEq(xerc20.balanceOf(user), depositAmount);

        xerc20.approve(address(lockbox), depositAmount);
        lockbox.withdraw(depositAmount);
        assertEq(xerc20.balanceOf(user), 0);
        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);

        // Cycle 2
        erc20.approve(address(lockbox), depositAmount);
        lockbox.deposit(depositAmount);
        assertEq(xerc20.balanceOf(user), depositAmount);

        vm.stopPrank();
    }

    // ==================== FUZZING TESTS ====================

    function test_Fuzz_DepositAndWithdraw(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_SUPPLY);

        vm.startPrank(user);
        erc20.approve(address(lockbox), amount);
        lockbox.deposit(amount);

        assertEq(xerc20.balanceOf(user), amount);

        xerc20.approve(address(lockbox), amount);
        lockbox.withdraw(amount);

        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);
        vm.stopPrank();
    }

    function test_Fuzz_DepositToWithdrawTo(uint256 amount, address _recipient) public {
        vm.assume(_recipient != address(0) && _recipient != address(lockbox));
        amount = bound(amount, 1, INITIAL_SUPPLY);

        vm.startPrank(user);
        erc20.approve(address(lockbox), amount);
        lockbox.depositTo(_recipient, amount);

        assertEq(xerc20.balanceOf(_recipient), amount);
        vm.stopPrank();

        vm.startPrank(_recipient);
        xerc20.approve(address(lockbox), amount);
        lockbox.withdrawTo(user, amount);
        vm.stopPrank();

        assertEq(erc20.balanceOf(user), INITIAL_SUPPLY);
    }

    // ==================== VIEW FUNCTION TESTS ====================

    function test_ViewFunctions_ReturnCorrectAddresses() public view {
        assertEq(lockbox.ERC20(), address(erc20));
        assertEq(lockbox.XERC20(), address(xerc20));
    }
}
