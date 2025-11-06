// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {xANDEToken} from "../../src/xERC20/xANDEToken.sol";
import {XERC20Lockbox} from "../../src/xERC20/XERC20Lockbox.sol";
import {ANDETokenDuality as ANDEToken} from "../../src/ANDETokenDuality.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IXERC20} from "../../src/interfaces/IXERC20.sol";

/**
 * @title xANDETokenTest
 * @notice Test suite for xANDE token and its lockbox integration
 * @dev Tests the complete flow: ANDE → xANDE via lockbox → bridging
 */
contract xANDETokenTest is Test {
    xANDEToken public xande;
    ANDEToken public ande;
    XERC20Lockbox public lockbox;

    address public admin;
    address public minter;
    address public bridge1;
    address public user;
    address public recipient;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");

    uint256 constant INITIAL_ANDE_SUPPLY = 1_000_000 ether;

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        bridge1 = makeAddr("bridge1");
        user = makeAddr("user");
        recipient = makeAddr("recipient");

        // Deploy native ANDE token
        ANDEToken andeImpl = new ANDEToken();
        bytes memory andeData = abi.encodeWithSelector(ANDEToken.initialize.selector, admin, minter);
        ERC1967Proxy andeProxy = new ERC1967Proxy(address(andeImpl), andeData);
        ande = ANDEToken(address(andeProxy));

        // Mint some ANDE to user
        vm.prank(minter);
        ande.mint(user, INITIAL_ANDE_SUPPLY);

        // Deploy xANDE token
        xANDEToken xandeImpl = new xANDEToken();
        bytes memory xandeData = abi.encodeWithSelector(xANDEToken.initialize.selector, admin);
        ERC1967Proxy xandeProxy = new ERC1967Proxy(address(xandeImpl), xandeData);
        xande = xANDEToken(address(xandeProxy));

        // Deploy lockbox
        lockbox = new XERC20Lockbox(address(xande), address(ande));

        // Set lockbox in xANDE
        vm.prank(admin);
        xande.setLockbox(address(lockbox));
    }

    // ==================== INITIALIZATION TESTS ====================

    function test_Initialize_HasCorrectNameAndSymbol() public view {
        assertEq(xande.name(), "Cross-Chain ANDE");
        assertEq(xande.symbol(), "xANDE");
    }

    function test_Initialize_SetsCorrectRoles() public view {
        assertTrue(xande.hasRole(xande.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(xande.hasRole(BRIDGE_MANAGER_ROLE, admin));
    }

    // ==================== LOCKBOX INTEGRATION TESTS ====================

    function test_Lockbox_UserCanWrapANDEToXANDE() public {
        uint256 wrapAmount = 100 ether;

        vm.startPrank(user);
        ande.approve(address(lockbox), wrapAmount);
        lockbox.deposit(wrapAmount);
        vm.stopPrank();

        assertEq(xande.balanceOf(user), wrapAmount);
        assertEq(ande.balanceOf(user), INITIAL_ANDE_SUPPLY - wrapAmount);
        assertEq(ande.balanceOf(address(lockbox)), wrapAmount);
    }

    function test_Lockbox_UserCanUnwrapXANDEToANDE() public {
        uint256 wrapAmount = 100 ether;

        vm.startPrank(user);
        // First wrap
        ande.approve(address(lockbox), wrapAmount);
        lockbox.deposit(wrapAmount);

        // Then unwrap
        xande.approve(address(lockbox), wrapAmount);
        lockbox.withdraw(wrapAmount);
        vm.stopPrank();

        assertEq(xande.balanceOf(user), 0);
        assertEq(ande.balanceOf(user), INITIAL_ANDE_SUPPLY);
    }

    function test_Lockbox_CanWrapAndUnwrapMultipleTimes() public {
        uint256 amount1 = 100 ether;
        uint256 amount2 = 50 ether;

        vm.startPrank(user);

        // Cycle 1
        ande.approve(address(lockbox), amount1);
        lockbox.deposit(amount1);
        assertEq(xande.balanceOf(user), amount1);

        xande.approve(address(lockbox), amount1);
        lockbox.withdraw(amount1);
        assertEq(xande.balanceOf(user), 0);

        // Cycle 2 with different amount
        ande.approve(address(lockbox), amount2);
        lockbox.deposit(amount2);
        assertEq(xande.balanceOf(user), amount2);

        vm.stopPrank();
    }

    // ==================== BRIDGE FUNCTIONALITY TESTS ====================

    function test_Bridge_AdminCanSetBridgeLimits() public {
        uint256 mintLimit = 10_000 ether;
        uint256 burnLimit = 5_000 ether;

        vm.prank(admin);
        xande.setLimits(bridge1, mintLimit, burnLimit);

        assertEq(xande.mintingMaxLimitOf(bridge1), mintLimit);
        assertEq(xande.burningMaxLimitOf(bridge1), burnLimit);
    }

    function test_Bridge_CanMintWithinLimits() public {
        uint256 mintLimit = 10_000 ether;
        vm.prank(admin);
        xande.setLimits(bridge1, mintLimit, 0);

        uint256 mintAmount = 5_000 ether;
        vm.prank(bridge1);
        xande.mint(recipient, mintAmount);

        assertEq(xande.balanceOf(recipient), mintAmount);
    }

    function test_Bridge_CanBurnWithinLimits() public {
        uint256 burnLimit = 10_000 ether;
        vm.prank(admin);
        xande.setLimits(bridge1, 10_000 ether, burnLimit);

        // Mint tokens first
        vm.prank(bridge1);
        xande.mint(recipient, 5_000 ether);

        // Approve bridge
        vm.prank(recipient);
        xande.approve(bridge1, 3_000 ether);

        // Bridge burns
        vm.prank(bridge1);
        xande.burn(recipient, 3_000 ether);

        assertEq(xande.balanceOf(recipient), 2_000 ether);
    }

    // ==================== COMPLETE FLOW TESTS ====================

    function test_CompleteFlow_NativeChainToDestinationChain() public {
        uint256 bridgeAmount = 500 ether;

        // Step 1: User wraps ANDE to xANDE on native chain
        vm.startPrank(user);
        ande.approve(address(lockbox), bridgeAmount);
        lockbox.deposit(bridgeAmount);
        vm.stopPrank();

        assertEq(xande.balanceOf(user), bridgeAmount);
        assertEq(ande.balanceOf(address(lockbox)), bridgeAmount);

        // Step 2: Setup bridge on destination chain
        vm.prank(admin);
        xande.setLimits(bridge1, 1_000_000 ether, 1_000_000 ether);

        // Step 3: User initiates bridge transfer (simulated)
        // On native chain: burn xANDE
        vm.prank(user);
        xande.approve(bridge1, bridgeAmount);

        vm.prank(bridge1);
        xande.burn(user, bridgeAmount);

        assertEq(xande.balanceOf(user), 0);

        // Step 4: On destination chain: bridge mints xANDE
        vm.prank(bridge1);
        xande.mint(recipient, bridgeAmount);

        assertEq(xande.balanceOf(recipient), bridgeAmount);
    }

    function test_CompleteFlow_ReturnFromDestinationToNative() public {
        uint256 bridgeAmount = 500 ether;

        // Setup: User has xANDE on destination chain
        vm.prank(admin);
        xande.setLimits(bridge1, 1_000_000 ether, 1_000_000 ether);

        vm.prank(bridge1);
        xande.mint(user, bridgeAmount);

        // Step 1: User burns xANDE on destination chain
        vm.prank(user);
        xande.approve(bridge1, bridgeAmount);

        vm.prank(bridge1);
        xande.burn(user, bridgeAmount);

        // Step 2: On native chain, wrap some ANDE first (to have balance in lockbox)
        address nativeUser = makeAddr("nativeUser");
        vm.prank(minter);
        ande.mint(nativeUser, bridgeAmount);

        vm.startPrank(nativeUser);
        ande.approve(address(lockbox), bridgeAmount);
        lockbox.deposit(bridgeAmount);
        vm.stopPrank();

        // Step 3: Bridge mints xANDE to user on native chain
        vm.prank(bridge1);
        xande.mint(user, bridgeAmount);

        // Step 4: User unwraps xANDE to get native ANDE
        uint256 userAndeBalanceBefore = ande.balanceOf(user);
        vm.startPrank(user);
        xande.approve(address(lockbox), bridgeAmount);
        lockbox.withdraw(bridgeAmount);
        vm.stopPrank();

        // Verify user received bridgeAmount of ANDE
        assertEq(ande.balanceOf(user), userAndeBalanceBefore + bridgeAmount);
    }

    // ==================== ERC20 STANDARD TESTS ====================

    function test_ERC20_TransferWorks() public {
        uint256 amount = 100 ether;

        // Wrap some ANDE first
        vm.startPrank(user);
        ande.approve(address(lockbox), amount);
        lockbox.deposit(amount);

        // Transfer xANDE
        xande.transfer(recipient, amount);
        vm.stopPrank();

        assertEq(xande.balanceOf(user), 0);
        assertEq(xande.balanceOf(recipient), amount);
    }

    function test_ERC20_ApproveAndTransferFromWorks() public {
        uint256 amount = 100 ether;

        vm.startPrank(user);
        ande.approve(address(lockbox), amount);
        lockbox.deposit(amount);

        xande.approve(recipient, amount);
        vm.stopPrank();

        vm.prank(recipient);
        xande.transferFrom(user, recipient, amount);

        assertEq(xande.balanceOf(recipient), amount);
    }

    // ==================== SECURITY TESTS ====================

    function test_Security_OnlyAuthorizedBridgesCanMint() public {
        address unauthorizedBridge = makeAddr("unauthorizedBridge");

        vm.prank(unauthorizedBridge);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xande.mint(user, 100 ether);
    }

    function test_Security_OnlyAdminCanSetLimits() public {
        address nonAdmin = makeAddr("nonAdmin");

        vm.prank(nonAdmin);
        vm.expectRevert();
        xande.setLimits(bridge1, 1000 ether, 1000 ether);
    }

    function test_Security_OnlyAdminCanSetLockbox() public {
        address newLockbox = makeAddr("newLockbox");
        address nonAdmin = makeAddr("nonAdmin");

        vm.prank(nonAdmin);
        vm.expectRevert();
        xande.setLockbox(newLockbox);
    }

    // ==================== EDGE CASES ====================

    function test_EdgeCase_MultipleBridgesCanOperateIndependently() public {
        address bridge2 = makeAddr("bridge2");

        vm.startPrank(admin);
        xande.setLimits(bridge1, 1000 ether, 500 ether);
        xande.setLimits(bridge2, 2000 ether, 1000 ether);
        vm.stopPrank();

        // Bridge 1 mints
        vm.prank(bridge1);
        xande.mint(user, 500 ether);

        // Bridge 2 mints
        vm.prank(bridge2);
        xande.mint(recipient, 1500 ether);

        assertEq(xande.balanceOf(user), 500 ether);
        assertEq(xande.balanceOf(recipient), 1500 ether);

        // Check limits are independent
        assertEq(xande.mintingCurrentLimitOf(bridge1), 500 ether);
        assertEq(xande.mintingCurrentLimitOf(bridge2), 500 ether);
    }

    function test_EdgeCase_LockboxBypassesRateLimits() public {
        // Even without setting any bridge limits, lockbox can mint unlimited
        uint256 largeAmount = 1_000_000 ether;

        vm.prank(minter);
        ande.mint(user, largeAmount);

        vm.startPrank(user);
        ande.approve(address(lockbox), largeAmount);
        lockbox.deposit(largeAmount);
        vm.stopPrank();

        assertEq(xande.balanceOf(user), largeAmount);
    }

    // ==================== FUZZING TESTS ====================

    function test_Fuzz_WrapAndUnwrap(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_ANDE_SUPPLY);

        vm.startPrank(user);
        ande.approve(address(lockbox), amount);
        lockbox.deposit(amount);

        assertEq(xande.balanceOf(user), amount);

        xande.approve(address(lockbox), amount);
        lockbox.withdraw(amount);

        assertEq(ande.balanceOf(user), INITIAL_ANDE_SUPPLY);
        vm.stopPrank();
    }
}
