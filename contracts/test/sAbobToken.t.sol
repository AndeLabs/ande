// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {sAbobToken} from "../src/sAbobToken.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract sAbobTokenTest is Test {
    sAbobToken public vault;
    AbobToken public abobToken;

    address public owner;
    address public user;
    address public yieldDepositor;

    bytes32 public constant YIELD_DEPOSITOR_ROLE = keccak256("YIELD_DEPOSITOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // --- 1. Crear Direcciones de Prueba ---
        owner = makeAddr("owner");
        user = makeAddr("user");
        yieldDepositor = makeAddr("yieldDepositor");

        // --- 2. Desplegar AbobToken (el activo subyacente) ---
        AbobToken abobImplementation = new AbobToken();
        bytes memory abobData = abi.encodeWithSelector(AbobToken.initialize.selector, owner, owner);
        ERC1967Proxy abobProxy = new ERC1967Proxy(address(abobImplementation), abobData);
        abobToken = AbobToken(address(abobProxy));

        // --- 3. Desplegar sAbobToken (el vault) ---
        sAbobToken vaultImplementation = new sAbobToken();
        bytes memory vaultData = abi.encodeWithSelector(sAbobToken.initialize.selector, owner, address(abobToken));
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), vaultData);
        vault = sAbobToken(address(vaultProxy));

        // --- 4. Configurar Roles y Fondos ---
        vm.prank(owner);
        vault.grantRole(YIELD_DEPOSITOR_ROLE, yieldDepositor);

        // El owner ya es minter desde la inicialización de AbobToken.
        // Ahora, como owner, minteamos tokens para los usuarios de prueba.
        vm.startPrank(owner);
        abobToken.mint(user, 1000 * 1e18);
        abobToken.mint(yieldDepositor, 100 * 1e18);
        vm.stopPrank();
    }

    // --- Test Group: Deployment ---

    function test_Deployment_CorrectAsset() public view {
        assertEq(vault.asset(), address(abobToken), "Asset should be AbobToken");
    }

    function test_Deployment_CorrectNameAndSymbol() public view {
        assertEq(vault.name(), "Staked ABOB", "Name should be Staked ABOB");
        assertEq(vault.symbol(), "sABOB", "Symbol should be sABOB");
    }

    // --- Test Group: Core ERC4626 Functions ---

    function test_Core_DepositAndReceiveShares() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user);
        abobToken.approve(address(vault), depositAmount);

        // El evento se emite con los datos correctos
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
        
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), depositAmount, "User should receive shares 1:1");
        assertEq(vault.totalAssets(), depositAmount, "Total assets should equal deposit");
    }

    function test_Core_RedeemSharesAndReceiveAssets() public {
        uint256 depositAmount = 100 * 1e18;
        vm.startPrank(user);
        abobToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user);
        vm.stopPrank();

        uint256 shares = vault.balanceOf(user);
        uint256 userInitialAbob = abobToken.balanceOf(user);

        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(user, user, user, shares, shares);

        vault.redeem(shares, user, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 0, "User shares should be 0");
        assertEq(abobToken.balanceOf(user), userInitialAbob + depositAmount, "User ABOB balance should be restored");
    }

    // --- Test Group: Yield Accrual ---

    function test_Yield_ShareValueIncreases() public {
        uint256 userDeposit = 100 * 1e18;
        uint256 yieldAmount = 10 * 1e18;

        // 1. User deposits 100 ABOB, gets 100 sABOB shares
        vm.startPrank(user);
        abobToken.approve(address(vault), userDeposit);
        vault.deposit(userDeposit, user);
        vm.stopPrank();

        uint256 userShares = vault.balanceOf(user);
        assertEq(userShares, userDeposit, "Initial shares should be 1:1");

        // 2. Yield depositor adds 10 ABOB as yield
        vm.startPrank(yieldDepositor);
        abobToken.approve(address(vault), yieldAmount);
        vault.depositYield(yieldAmount);
        vm.stopPrank();

        // 3. Total assets in vault are now 110 ABOB
        assertEq(vault.totalAssets(), userDeposit + yieldAmount, "Total assets should include yield");

        // 4. User's 100 shares should now be worth 110 ABOB
        uint256 assetsOut = vault.previewRedeem(userShares);
        assertApproxEqAbs(assetsOut, userDeposit + yieldAmount, 1, "100 shares should be worth ~110 assets");
    }

    function test_Yield_OnlyDepositorRoleCanDeposit() public {
        uint256 yieldAmount = 10 * 1e18;

        vm.startPrank(user);
        abobToken.approve(address(vault), yieldAmount);
        
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, YIELD_DEPOSITOR_ROLE));
        vault.depositYield(yieldAmount);
        vm.stopPrank();
    }
}
