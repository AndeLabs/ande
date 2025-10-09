// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {P2POracle} from "../src/P2POracle.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {AndeOracleAggregator} from "../src/AndeOracleAggregator.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract DeployAndTestP2POracle is Script {
    P2POracle public p2pOracle;
    ANDEToken public andeToken;
    AndeOracleAggregator public aggregator;
    MockERC20 public mockUsdc;

    uint256 public constant TEST_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant TEST_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        vm.startBroadcast(TEST_PRIVATE_KEY);

        // 1. Desplegar token ANDE
        console.log("1. Desplegando ANDE Token...");
        andeToken = new ANDEToken();
        console.log("   ANDE Token desplegado en:", address(andeToken));

        // 2. Desplegar mock USDC para pruebas
        console.log("2. Desplegando Mock USDC...");
        mockUsdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("   Mock USDC desplegado en:", address(mockUsdc));

        // 3. Desplegar P2POracle
        console.log("3. Desplegando P2POracle...");
        uint256 minStake = 100 * 1e18; // 100 ANDE minimo
        uint256 epochDuration = 3600; // 1 hora por epoch

        p2pOracle = new P2POracle();
        p2pOracle.initialize(
            TEST_ADDRESS, // admin
            address(andeToken), // ANDE token
            minStake,
            epochDuration
        );
        console.log("   P2POracle desplegado en:", address(p2pOracle));

        // 4. Desplegar AndeOracleAggregator
        console.log("4. Desplegando AndeOracleAggregator...");
        aggregator = new AndeOracleAggregator();
        aggregator.initialize(TEST_ADDRESS, address(p2pOracle));
        console.log("   AndeOracleAggregator desplegado en:", address(aggregator));

        vm.stopBroadcast();

        // 5. Pruebas del flujo completo
        console.log("=== TEST COMPLETED ===");

        // Mint tokens de prueba
        _mintTestTokens();

        // Registrar reporters
        _registerReporters();

        // Enviar precios
        _reportPrices();

        // Finalizar epoch
        _finalizeEpoch();

        // Verificar agregador
        _verifyAggregator();

        console.log("=== TEST COMPLETED ===");
    }

    function _mintTestTokens() internal {
        console.log("5. Minteando tokens de prueba...");

        // Mint ANDE tokens para el test address
        andeToken.mint(TEST_ADDRESS, 1000000 * 1e18);
        console.log("   SUCCESS 1M ANDE tokens minteados");

        // Mint ANDE tokens para reporters adicionales
        address[3] memory reporters = [
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            0x90F79bf6EB2c4f870365E785982E1f101E93b906
        ];

        for (uint i = 0; i < reporters.length; i++) {
            andeToken.mint(reporters[i], 100000 * 1e18);
            console.log("   SUCCESS 100k ANDE tokens minteados para reporter", i + 1);
        }
    }

    function _registerReporters() internal {
        console.log("6. Registrando reporters...");

        // Approve ANDE tokens para staking
        andeToken.approve(address(p2pOracle), 1000000 * 1e18);

        // Registrar reporter principal
        vm.startBroadcast(TEST_PRIVATE_KEY);
        p2pOracle.register();
        vm.stopBroadcast();
        console.log("   SUCCESS Reporter principal registrado");

        // Registrar reporters adicionales
        uint256[3] memory privateKeys = [
            uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d),
            uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a),
            uint256(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6)
        ];

        address[3] memory reporters = [
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            0x90F79bf6EB2c4f870365E785982E1f101E93b906
        ];

        for (uint i = 0; i < reporters.length; i++) {
            vm.startBroadcast(privateKeys[i]);
            andeToken.approve(address(p2pOracle), 100000 * 1e18);
            p2pOracle.register();
            vm.stopBroadcast();
            console.log("   SUCCESS Reporter", i + 1, "registrado");
        }
    }

    function _reportPrices() internal {
        console.log("7. Enviando precios...");

        // Precio de ejemplo: 6.91 BOB por USD
        // El contrato espera el precio de 1 BOB en USD con 18 decimales
        // Simplified: just use whole numbers

        uint256[3] memory privateKeys = [
            uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d),
            uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a),
            uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a)
        ];

        // Reporter 1: 6.90 BOB/USD (1 BOB = 0.1449 USD)
        vm.startBroadcast(privateKeys[0]);
        uint256 price1 = 144900000000000000; // 0.1449 * 1e18
        p2pOracle.reportPrice(price1);
        vm.stopBroadcast();
        console.log("   SUCCESS Reporter 1: 6.90 BOB/USD");

        // Reporter 2: 6.91 BOB/USD (1 BOB = 0.1447 USD)
        vm.startBroadcast(privateKeys[1]);
        uint256 price2 = 144700000000000000; // 0.1447 * 1e18
        p2pOracle.reportPrice(price2);
        vm.stopBroadcast();
        console.log("   SUCCESS Reporter 2: 6.91 BOB/USD");

        // Reporter 3: 6.92 BOB/USD (1 BOB = 0.1445 USD)
        vm.startBroadcast(privateKeys[2]);
        uint256 price3 = 144500000000000000; // 0.1445 * 1e18
        p2pOracle.reportPrice(price3);
        vm.stopBroadcast();
        console.log("   SUCCESS Reporter 3: 6.92 BOB/USD");
    }

    function _finalizeEpoch() internal {
        console.log("8. Finalizando epoch...");

        vm.startBroadcast(TEST_PRIVATE_KEY);
        p2pOracle.finalizeCurrentEpoch();
        vm.stopBroadcast();

        console.log("   SUCCESS Epoch finalizado");
    }

    function _verifyAggregator() internal {
        console.log("9. Verificando AndeOracleAggregator...");

        // Obtener datos del oraculo
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = aggregator.latestRoundData();

        console.log("   DATA Datos del oraculo:");
        console.log("      Round ID:", uint256(roundId));
        console.log("      Answer:", uint256(answer));
        console.log("      Started At:", startedAt);
        console.log("      Updated At:", updatedAt);
        console.log("      Answered In Round:", uint256(answeredInRound));

        // Verificar que el precio sea razonable (deberia estar cerca de la mediana)
        // La mediana de [6.90, 6.91, 6.92] es 6.91 (1 BOB = 0.1447 USD)
        uint256 expectedPrice = 144700000000000000; // 0.1447 * 1e18

        require(uint256(answer) > (expectedPrice * 99) / 100, "Price too low");
        require(uint256(answer) < (expectedPrice * 101) / 100, "Price too high");

        console.log("   SUCCESS Precio verificado dentro del rango esperado");
    }
}