// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {P2POracleV2} from "../../src/P2POracleV2.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Pruebas de Integración del Ecosistema ABOB
 * @notice Verifica la correcta interacción entre AbobToken y P2POracleV2.
 */
contract IntegrationTest is Test {
    // === Contratos ===
    AbobToken public abobToken;
    P2POracleV2 public p2pAndeOracle;
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
        // --- 1. Desplegar Tokens y Mocks ---
        ausd = new MockERC20("Mock AUSD", "mAUSD", 18);
        ande = new MockERC20("Mock ANDE", "mANDE", 18);
        abobOracle = new MockOracle(int256(ABOB_PRICE), 18);

        // --- 2. Desplegar y Configurar P2POracleV2 ---
        P2POracleV2 p2pImpl = new P2POracleV2();
        bytes memory p2pInitData = abi.encodeWithSelector(
            P2POracleV2.initialize.selector,
            admin,
            address(ande),
            ORACLE_MIN_STAKE,
            ORACLE_EPOCH_DURATION
        );
        ERC1967Proxy p2pProxy = new ERC1967Proxy(address(p2pImpl), p2pInitData);
        p2pAndeOracle = P2POracleV2(address(p2pProxy));

        vm.startPrank(admin);
        p2pAndeOracle.grantRole(p2pAndeOracle.FINALIZER_ROLE(), finalizer);
        vm.stopPrank();

        // --- 3. Desplegar y Configurar AbobToken ---
        AbobToken abobImpl = new AbobToken();
        bytes memory abobInitData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin, // admin
            admin, // pauser
            admin, // governance
            address(ausd),
            address(ande),
            address(p2pAndeOracle), // Usando nuestro oráculo P2P real
            address(abobOracle),
            7000 // 70% collateral ratio
        );
        ERC1967Proxy abobProxy = new ERC1967Proxy(address(abobImpl), abobInitData);
        abobToken = AbobToken(address(abobProxy));

        // --- 4. Preparar a los Reporters ---
        address[3] memory reporters = [reporter1, reporter2, reporter3];
        for (uint i = 0; i < reporters.length; i++) {
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

        // --- 5. Preparar al Usuario Final ---
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

        // El precio mediano debería ser 2.1 (dado que todos tienen el mismo stake)
        uint256 expectedMedianPrice = price2;

        // --- 4. Actuar (Usuario) ---
        uint256 abobToMint = 100e18;
        uint256 userAndeBalanceBefore = ande.balanceOf(user);

        vm.prank(user);
        abobToken.mint(abobToMint);

        // --- 5. Verificar --- 
        // Calculamos el colateral ANDE esperado usando el precio mediano del oráculo
        uint256 totalCollateralValue = (abobToMint * ABOB_PRICE) / 1e18;
        uint256 ausdCollateral = (totalCollateralValue * 7000) / 10000;
        uint256 andeCollateralValue = totalCollateralValue - ausdCollateral;
        uint256 expectedAndeAmount = (andeCollateralValue * 1e18) / expectedMedianPrice;

        uint256 userAndeBalanceAfter = ande.balanceOf(user);

        assertEq(userAndeBalanceBefore - userAndeBalanceAfter, expectedAndeAmount, unicode"La cantidad de ANDE cobrada no coincide con el precio del oráculo P2P");
    }
}
