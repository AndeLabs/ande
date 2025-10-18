// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {P2POracle} from "../../src/P2POracle.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Pruebas de Integración del Ecosistema ABOB
 * @notice Verifica la correcta interacción entre AbobToken y P2POracle.
 */
contract IntegrationTest is Test {
    // === Contratos ===
    AbobToken public abobToken;
    P2POracle public p2pAndeOracle;
    MockERC20 public ausd;
    MockERC20 public ande;
    MockOracle public abobOracle; // Mock para el precio de ABOB, que no es parte de esta prueba

    // === Actores ===
    address public admin = makeAddr("admin");
    address public finalizer = makeAddr("finalizer");
    address public user = makeAddr("user");
    address public reporter1 = makeAddr("reporter1");
    address public reporter2 = makeAddr("reporter2");
    address public reporter3 = makeAddr("reporter3");

    // === Constantes de Configuración ===
    uint256 public constant ORACLE_MIN_STAKE = 100e18;
    uint256 public constant ORACLE_EPOCH_DURATION = 1 hours;
    uint256 public constant ABOB_PRICE = 1 * 1e18; // $1

    function setUp() public {
        console.log("=== SETUP INICIADO ===");

        // --- 1. Desplegar Tokens y Mocks ---
        console.log("Paso 1: Desplegando mocks...");
        ausd = new MockERC20("Mock AUSD", "mAUSD", 18);
        ande = new MockERC20("Mock ANDE", "mANDE", 18);
        abobOracle = new MockOracle(int256(ABOB_PRICE), 18);
        console.log("Paso 1: Completado");

        // --- 2. Desplegar y Configurar P2POracle ---
        console.log("Paso 2: Desplegando P2POracle...");
        P2POracle p2pImpl = new P2POracle();
        bytes memory p2pInitData = abi.encodeWithSelector(
            P2POracle.initialize.selector, admin, address(ande), ORACLE_MIN_STAKE, ORACLE_EPOCH_DURATION
        );
        ERC1967Proxy p2pProxy = new ERC1967Proxy(address(p2pImpl), p2pInitData);
        p2pAndeOracle = P2POracle(address(p2pProxy));

        vm.startPrank(admin);
        p2pAndeOracle.grantRole(p2pAndeOracle.FINALIZER_ROLE(), finalizer);
        vm.stopPrank();
        console.log("Paso 2: Completado");

        // --- 3. Desplegar y Configurar AbobToken ---
        console.log("Paso 3: Desplegando AbobToken...");
        AbobToken abobImpl = new AbobToken();
        bytes memory abobInitData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin, // admin
            admin, // pauser
            admin, // governance
            address(abobOracle), // priceOracle
            address(0), // Sin CollateralManager - usa fallback local
            address(0) // Sin LiquidationManager
        );
        ERC1967Proxy abobProxy = new ERC1967Proxy(address(abobImpl), abobInitData);
        abobToken = AbobToken(payable(address(abobProxy)));
        console.log("Paso 3: Completado");

        // --- 4. Configurar colateral ANDE manualmente ---
        console.log("Paso 4: Configurando colateral...");
        vm.startPrank(admin);
        abobToken.addCollateral(
            address(ande),
            12000, // 120% collateral ratio
            11000, // 110% liquidation threshold (debe ser >= 100%)
            1_000_000 * 1e18, // 1M ABOB debt ceiling
            100 * 1e18, // 100 ABOB minimum deposit
            address(p2pAndeOracle) // Usar P2P oracle para precios
        );
        vm.stopPrank();
        console.log("Paso 4: Completado");

        // --- 6. Preparar a los Reporters ---
        address[3] memory reporters = [reporter1, reporter2, reporter3];
        for (uint256 i = 0; i < reporters.length; i++) {
            address r = reporters[i];
            // Darles ANDE para el stake
            ande.mint(r, ORACLE_MIN_STAKE);
            // Aprobar al oráculo para que tome el stake
            vm.startPrank(r);
            ande.approve(address(p2pAndeOracle), ORACLE_MIN_STAKE);
            // Registrarse
            p2pAndeOracle.register();
            vm.stopPrank();
        }

        // --- 7. Preparar al Usuario Final ---
        ausd.mint(user, 1000e18);
        ande.mint(user, 1000e18);
        vm.startPrank(user);
        ausd.approve(address(abobToken), type(uint256).max);
        ande.approve(address(abobToken), type(uint256).max);
        vm.stopPrank();
    }

    function test_Mint_With_P2POracle_Price() public {
        // --- 1. Actuar (Reporters) ---
        uint256 price1 = 2.0 * 1e18;
        uint256 price2 = 2.1 * 1e18;
        uint256 price3 = 2.2 * 1e18;

        vm.prank(reporter1);
        p2pAndeOracle.reportPrice(price1);
        vm.prank(reporter2);
        p2pAndeOracle.reportPrice(price2);
        vm.prank(reporter3);
        p2pAndeOracle.reportPrice(price3);

        // --- 2. Actuar (Avanzar en el Tiempo) ---
        // Avanzamos el tiempo para pasar a la siguiente época y poder finalizar la actual
        vm.warp(block.timestamp + ORACLE_EPOCH_DURATION);

        // --- 3. Actuar (Finalizer) ---
        vm.prank(finalizer);
        p2pAndeOracle.finalizeCurrentEpoch();

        // Obtener el precio real del oráculo (el que realmente se usa)
        (, int256 actualPriceInt,,,) = p2pAndeOracle.latestRoundData();
        uint256 actualPrice = uint256(actualPriceInt);
        console.log("Actual oracle price:", actualPrice / 1e18);

        // --- 4. Actuar (Usuario) ---
        uint256 abobToMint = 100e18;
        uint256 userAndeBalanceBefore = ande.balanceOf(user);

        vm.prank(user);
        // Deposit ANDE collateral and mint ABOB
        uint256 collateralAmount = 200e18; // 200 ANDE as collateral (200% overcollateralization for 100 ABOB)
        abobToken.depositCollateralAndMint(address(ande), collateralAmount, abobToMint);

        // --- 5. Verificar ---
        uint256 userAndeBalanceAfter = ande.balanceOf(user);
        uint256 actualAndeUsed = userAndeBalanceBefore - userAndeBalanceAfter;

        console.log("=== DEBUG CALCULATIONS ===");
        console.log("ABOB to mint:", abobToMint / 1e18);
        console.log("ANDE deposited:", collateralAmount / 1e18);
        console.log("ANDE actually used:", actualAndeUsed / 1e18);
        console.log("Oracle price used:", actualPrice / 1e18);
        console.log("ABOB Balance after:", abobToken.balanceOf(user) / 1e18);

        // Verificar que el ABOB fue minteado correctamente
        assertEq(abobToken.balanceOf(user), abobToMint, "ABOB minted incorrectly");

        // Verificar que el vault tiene el colateral correcto
        uint256 vaultCollateralValue = abobToken.getCollateralValue(user, address(ande));
        console.log("Collateral value in vault:", vaultCollateralValue / 1e18);

        // Por ahora, verificamos que la lógica básica funciona
        assertTrue(actualAndeUsed > 0, "Must use some ANDE collateral");
        assertTrue(actualAndeUsed <= collateralAmount, "Cannot use more ANDE than deposited");
        assertTrue(vaultCollateralValue > 0, "Vault must have collateral value");

        // El test principal: verificar que el sistema funciona end-to-end
        // ABOB fue minteado, colateral fue depositado, y todo está en el vault
        assertEq(abobToken.balanceOf(user), abobToMint, "ABOB should be minted correctly");
    }
}
