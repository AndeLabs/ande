// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {StabilityEngine} from "../src/StabilityEngine.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {AusdToken} from "../src/AusdToken.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {P2POracleV2} from "../src/P2POracleV2.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockOracle} from "../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StabilityEngineTest is Test {
    // --- Contracts ---
    StabilityEngine public engine;
    AbobToken public abobToken;
    AusdToken public ausdToken;
    ANDEToken public andeToken;
    P2POracleV2 public p2pOracle;
    MockERC20 public usdcCollateral;
    MockOracle public usdcOracle;

    // --- Users ---
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public finalizer = makeAddr("finalizer"); // Same as owner for simplicity

    function setUp() public {
        // ==============================================
        // 1. DESPLEGAR CONTRATOS (ECOSISTEMA COMPLETO)
        // ==============================================
        usdcCollateral = new MockERC20("Mock USDC", "USDC", 6);
        usdcOracle = new MockOracle();
        usdcOracle.setPrice(1 * 10**8); // 1 USD

        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, owner, owner))));
        p2pOracle = P2POracleV2(address(new ERC1967Proxy(address(new P2POracleV2()), abi.encodeWithSelector(P2POracleV2.initialize.selector, owner, address(andeToken), 1000 * 1e18, 3600))));
        ausdToken = AusdToken(address(new ERC1967Proxy(address(new AusdToken()), abi.encodeWithSelector(AusdToken.initialize.selector, owner))));
        abobToken = AbobToken(address(new ERC1967Proxy(address(new AbobToken()), abi.encodeWithSelector(AbobToken.initialize.selector, owner, owner))));
        engine = StabilityEngine(address(new ERC1967Proxy(address(new StabilityEngine()), abi.encodeWithSelector(StabilityEngine.initialize.selector, owner, address(abobToken), address(ausdToken), address(andeToken), address(p2pOracle)))));

        // ==============================================
        // 2. CONFIGURACIÓN DEL SISTEMA (TODO COMO OWNER)
        // ==============================================
        vm.startPrank(owner);

        // --- Roles ---
        abobToken.grantRole(abobToken.MINTER_ROLE(), address(engine));
        ausdToken.grantRole(ausdToken.COLLATERAL_MANAGER_ROLE(), owner);
        p2pOracle.grantRole(p2pOracle.FINALIZER_ROLE(), owner);

        // --- Fondos para el Owner (para el stake) ---
        andeToken.mint(owner, 10000 * 1e18);

        // --- Colateral y Oráculo ---
        ausdToken.addCollateralType(address(usdcCollateral), 12000, address(usdcOracle)); // 120%
        andeToken.approve(address(p2pOracle), 1000 * 1e18);
        p2pOracle.register();
        p2pOracle.reportPrice(2 * 1e18); // ANDE price = $2
        vm.warp(block.timestamp + 3601);
        p2pOracle.finalizeCurrentEpoch();

        // --- Fondos para el Usuario ---
        andeToken.mint(user, 100 * 1e18); // 100 ANDE
        
        vm.stopPrank();

        // --- Fondos Mock (no requieren rol) ---
        usdcCollateral.mint(user, 240 * 10**6); // 240 USDC

        // --- Usuario acuña AUSD ---
        vm.startPrank(user);
        usdcCollateral.approve(address(ausdToken), 240 * 10**6);
        ausdToken.depositAndMint(address(usdcCollateral), 240 * 10**6); // Mints 200 AUSD
        vm.stopPrank();
    }

    // --- PRUEBAS ---

    function test_Setup_UserHasCorrectInitialBalances() public view {
        assertEq(ausdToken.balanceOf(user), 200 * 1e18, "User should have 200 AUSD");
        assertEq(andeToken.balanceOf(user), 100 * 1e18, "User should have 100 ANDE");
    }

    function test_Mint_MintsAbobAndTakesCollateral() public {
        uint256 amountToMint = 100 * 1e18; // 100 ABOB
        uint256 expectedAusd = 80 * 1e18;  // 80% of 100
        uint256 expectedAnde = 10 * 1e18;  // 20% of 100 = 20 value / $2 price

        uint256 initialAusd = ausdToken.balanceOf(user);
        uint256 initialAnde = andeToken.balanceOf(user);

        vm.startPrank(user);
        ausdToken.approve(address(engine), expectedAusd);
        andeToken.approve(address(engine), expectedAnde);

        engine.mint(amountToMint);
        vm.stopPrank();

        assertEq(abobToken.balanceOf(user), amountToMint, "ABOB balance should be 100");
        assertEq(ausdToken.balanceOf(user), initialAusd - expectedAusd, "AUSD should be deducted");
        assertEq(andeToken.balanceOf(user), initialAnde - expectedAnde, "ANDE should be deducted");
    }

    function test_Burn_BurnsAbobAndReturnsCollateral() public {
        uint256 amountToBurn = 100 * 1e18; // 100 ABOB
        uint256 expectedAusdReturn = 80 * 1e18;
        uint256 expectedAndeReturn = 10 * 1e18;

        // Primero, el usuario necesita ABOB para quemar
        test_Mint_MintsAbobAndTakesCollateral();

        uint256 initialAusd = ausdToken.balanceOf(user);
        uint256 initialAnde = andeToken.balanceOf(user);

        vm.startPrank(user);
        abobToken.approve(address(engine), amountToBurn);
        engine.burn(amountToBurn);
        vm.stopPrank();

        assertEq(abobToken.balanceOf(user), 0, "ABOB balance should be 0");
        assertEq(ausdToken.balanceOf(user), initialAusd + expectedAusdReturn, "AUSD should be returned");
        assertEq(andeToken.balanceOf(user), initialAnde + expectedAndeReturn, "ANDE should be returned");
    }

    function test_Admin_CanSetRatio() public {
        vm.prank(owner);
        engine.setRatio(70, 30);

        (uint8 newAusd, uint8 newAnde) = engine.ratio();
        assertEq(newAusd, 70);
        assertEq(newAnde, 30);
    }

    function test_Fail_CannotSetInvalidRatio() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Ratios must sum to 100"));
        engine.setRatio(70, 29);
    }
}