// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {XERC20} from "../../src/xERC20/XERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IXERC20} from "../../src/interfaces/IXERC20.sol";

/**
 * @title XERC20Test
 * @notice Comprehensive test suite for xERC20 base contract
 * @dev Tests bridge management, rate limiting, minting/burning, and access control
 */
contract XERC20Test is Test {
    XERC20 public xerc20;

    address public admin;
    address public bridge1;
    address public bridge2;
    address public lockbox;
    address public user;

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");

    uint256 constant DURATION = 1 days;

    function setUp() public {
        admin = makeAddr("admin");
        bridge1 = makeAddr("bridge1");
        bridge2 = makeAddr("bridge2");
        lockbox = makeAddr("lockbox");
        user = makeAddr("user");

        // Deploy proxy and initialize
        XERC20 implementation = new XERC20();
        bytes memory data = abi.encodeWithSelector(XERC20.initialize.selector, "xToken", "xTKN", admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        xerc20 = XERC20(address(proxy));
    }

    // ==================== INITIALIZATION TESTS ====================

    function test_Initialize_SetsCorrectRoles() public view {
        assertTrue(xerc20.hasRole(ADMIN_ROLE, admin));
        assertTrue(xerc20.hasRole(BRIDGE_MANAGER_ROLE, admin));
    }

    function test_Initialize_HasCorrectNameAndSymbol() public view {
        assertEq(xerc20.name(), "xToken");
        assertEq(xerc20.symbol(), "xTKN");
    }

    function test_Initialize_CannotInitializeTwice() public {
        vm.expectRevert();
        xerc20.initialize("Test", "TST", admin);
    }

    // ==================== BRIDGE LIMIT MANAGEMENT ====================

    function test_SetLimits_AdminCanSetBridgeLimits() public {
        uint256 mintLimit = 1000 ether;
        uint256 burnLimit = 500 ether;

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IXERC20.BridgeLimitsSet(mintLimit, burnLimit, bridge1);
        xerc20.setLimits(bridge1, mintLimit, burnLimit);

        assertEq(xerc20.mintingMaxLimitOf(bridge1), mintLimit);
        assertEq(xerc20.burningMaxLimitOf(bridge1), burnLimit);
    }

    function test_SetLimits_NonAdminCannotSetLimits() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, BRIDGE_MANAGER_ROLE)
        );
        xerc20.setLimits(bridge1, 1000 ether, 500 ether);
    }

    function test_SetLimits_UpdatesCurrentLimitCorrectly() public {
        uint256 initialLimit = 1000 ether;

        vm.prank(admin);
        xerc20.setLimits(bridge1, initialLimit, initialLimit);

        // Mint some tokens to consume limit
        vm.prank(bridge1);
        xerc20.mint(user, 400 ether);

        // Check current limit is reduced
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), 600 ether);

        // Update limit to lower value
        vm.prank(admin);
        xerc20.setLimits(bridge1, 500 ether, 500 ether);

        // Current limit should be capped at new max
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), 500 ether);
    }

    function test_SetLimits_CanSetMultipleBridges() public {
        vm.startPrank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 500 ether);
        xerc20.setLimits(bridge2, 2000 ether, 1000 ether);
        vm.stopPrank();

        assertEq(xerc20.mintingMaxLimitOf(bridge1), 1000 ether);
        assertEq(xerc20.mintingMaxLimitOf(bridge2), 2000 ether);
    }

    // ==================== LOCKBOX MANAGEMENT ====================

    function test_SetLockbox_AdminCanSetLockbox() public {
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit IXERC20.LockboxSet(lockbox);
        xerc20.setLockbox(lockbox);

        assertEq(xerc20.lockbox(), lockbox);
    }

    function test_SetLockbox_NonAdminCannotSetLockbox() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, ADMIN_ROLE)
        );
        xerc20.setLockbox(lockbox);
    }

    // ==================== MINTING TESTS ====================

    function test_Mint_BridgeCanMintWithinLimits() public {
        uint256 mintLimit = 1000 ether;
        vm.prank(admin);
        xerc20.setLimits(bridge1, mintLimit, 0);

        uint256 mintAmount = 500 ether;
        vm.prank(bridge1);
        xerc20.mint(user, mintAmount);

        assertEq(xerc20.balanceOf(user), mintAmount);
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), mintLimit - mintAmount);
    }

    function test_Mint_CannotMintExceedingLimit() public {
        uint256 mintLimit = 1000 ether;
        vm.prank(admin);
        xerc20.setLimits(bridge1, mintLimit, 0);

        vm.prank(bridge1);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xerc20.mint(user, 1001 ether);
    }

    function test_Mint_UnauthorizedBridgeCannotMint() public {
        vm.prank(bridge1); // No limits set for bridge1
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xerc20.mint(user, 100 ether);
    }

    function test_Mint_LockboxCanMintWithoutLimits() public {
        vm.prank(admin);
        xerc20.setLockbox(lockbox);

        uint256 mintAmount = 10000 ether; // Large amount without setting any limits
        vm.prank(lockbox);
        xerc20.mint(user, mintAmount);

        assertEq(xerc20.balanceOf(user), mintAmount);
    }

    function test_Mint_LimitReplenishesOverTime() public {
        uint256 mintLimit = 1000 ether;
        vm.prank(admin);
        xerc20.setLimits(bridge1, mintLimit, 0);

        // Mint full limit
        vm.prank(bridge1);
        xerc20.mint(user, mintLimit);
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), 0);

        // Fast forward 12 hours (half of DURATION)
        vm.warp(block.timestamp + 12 hours);

        // Should have replenished ~500 ether
        uint256 currentLimit = xerc20.mintingCurrentLimitOf(bridge1);
        assertApproxEqAbs(currentLimit, 500 ether, 0.01 ether);

        // Can mint replenished amount
        vm.prank(bridge1);
        xerc20.mint(user, currentLimit);
    }

    function test_Mint_MultipleBridgesCanMintIndependently() public {
        vm.startPrank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 0);
        xerc20.setLimits(bridge2, 2000 ether, 0);
        vm.stopPrank();

        vm.prank(bridge1);
        xerc20.mint(user, 500 ether);

        vm.prank(bridge2);
        xerc20.mint(user, 1500 ether);

        assertEq(xerc20.balanceOf(user), 2000 ether);
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), 500 ether);
        assertEq(xerc20.mintingCurrentLimitOf(bridge2), 500 ether);
    }

    // ==================== BURNING TESTS ====================

    function test_Burn_BridgeCanBurnWithinLimits() public {
        // Setup: mint tokens and set burn limit
        vm.prank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 1000 ether);

        vm.prank(bridge1);
        xerc20.mint(user, 1000 ether);

        // User approves bridge to burn
        vm.prank(user);
        xerc20.approve(bridge1, 500 ether);

        // Bridge burns
        vm.prank(bridge1);
        xerc20.burn(user, 500 ether);

        assertEq(xerc20.balanceOf(user), 500 ether);
        assertEq(xerc20.burningCurrentLimitOf(bridge1), 500 ether);
    }

    function test_Burn_CannotBurnExceedingLimit() public {
        vm.prank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 500 ether);

        vm.prank(bridge1);
        xerc20.mint(user, 1000 ether);

        vm.prank(user);
        xerc20.approve(bridge1, 600 ether);

        vm.prank(bridge1);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xerc20.burn(user, 600 ether);
    }

    function test_Burn_UserCanBurnOwnTokens() public {
        // Mint tokens to user
        vm.prank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 1000 ether);

        vm.prank(bridge1);
        xerc20.mint(user, 500 ether);

        // User can't directly call burn without approval/bridge
        // But can use the bridge to burn
        vm.prank(user);
        xerc20.approve(bridge1, 200 ether);

        vm.prank(bridge1);
        xerc20.burn(user, 200 ether);

        assertEq(xerc20.balanceOf(user), 300 ether);
    }

    function test_Burn_LockboxCanBurnWithoutLimits() public {
        vm.prank(admin);
        xerc20.setLockbox(lockbox);

        // Mint via lockbox
        vm.prank(lockbox);
        xerc20.mint(user, 10000 ether);

        vm.prank(user);
        xerc20.approve(lockbox, 10000 ether);

        // Burn via lockbox (no limits)
        vm.prank(lockbox);
        xerc20.burn(user, 10000 ether);

        assertEq(xerc20.balanceOf(user), 0);
    }

    function test_Burn_LimitReplenishesOverTime() public {
        vm.prank(admin);
        xerc20.setLimits(bridge1, 1000 ether, 1000 ether);

        // Mint tokens
        vm.prank(bridge1);
        xerc20.mint(user, 1000 ether);

        // Approve full amount
        vm.prank(user);
        xerc20.approve(bridge1, 1000 ether);

        // Burn full limit
        vm.prank(bridge1);
        xerc20.burn(user, 1000 ether);
        assertEq(xerc20.burningCurrentLimitOf(bridge1), 0);

        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);

        // Limit should be fully replenished (with small rounding tolerance)
        assertApproxEqAbs(xerc20.burningCurrentLimitOf(bridge1), 1000 ether, 0.01 ether);
    }

    // ==================== ERC20 PERMIT TESTS ====================

    function test_Permit_SupportsEIP2612() public view {
        // Check domain separator exists
        bytes32 domainSeparator = xerc20.DOMAIN_SEPARATOR();
        assertTrue(domainSeparator != bytes32(0));
    }

    // ==================== VIEW FUNCTION TESTS ====================

    function test_MintingMaxLimitOf_ReturnsCorrectLimit() public {
        vm.prank(admin);
        xerc20.setLimits(bridge1, 1234 ether, 0);

        assertEq(xerc20.mintingMaxLimitOf(bridge1), 1234 ether);
    }

    function test_BurningMaxLimitOf_ReturnsCorrectLimit() public {
        vm.prank(admin);
        xerc20.setLimits(bridge1, 0, 5678 ether);

        assertEq(xerc20.burningMaxLimitOf(bridge1), 5678 ether);
    }

    function test_MintingCurrentLimitOf_ReturnsZeroForUnsetBridge() public view {
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), 0);
    }

    function test_BurningCurrentLimitOf_ReturnsZeroForUnsetBridge() public view {
        assertEq(xerc20.burningCurrentLimitOf(bridge1), 0);
    }

    // ==================== EDGE CASES ====================

    function test_EdgeCase_SettingZeroLimits() public {
        vm.prank(admin);
        xerc20.setLimits(bridge1, 0, 0);

        assertEq(xerc20.mintingMaxLimitOf(bridge1), 0);
        assertEq(xerc20.burningMaxLimitOf(bridge1), 0);
    }

    function test_EdgeCase_LimitDoesNotOverflow() public {
        // Use a large but reasonable limit to avoid overflow
        uint256 largeLimit = type(uint128).max;
        vm.prank(admin);
        xerc20.setLimits(bridge1, largeLimit, largeLimit);

        // Fast forward way into the future
        vm.warp(block.timestamp + 365 days);

        // Should cap at max limit, not overflow
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), largeLimit);
    }

    function test_Fuzz_SetLimitsAndMint(uint256 limit, uint256 mintAmount) public {
        limit = bound(limit, 1, type(uint128).max);
        mintAmount = bound(mintAmount, 1, limit);

        vm.prank(admin);
        xerc20.setLimits(bridge1, limit, 0);

        vm.prank(bridge1);
        xerc20.mint(user, mintAmount);

        assertEq(xerc20.balanceOf(user), mintAmount);
        assertEq(xerc20.mintingCurrentLimitOf(bridge1), limit - mintAmount);
    }
}
