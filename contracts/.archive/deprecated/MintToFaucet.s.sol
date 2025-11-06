// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TestToken} from "../src/TestToken.sol";

/**
 * @title MintToFaucet
 * @notice Script para mintear tokens ANDE al faucet para testing
 * @dev Solo para desarrollo y testnet
 */
contract MintToFaucet is Script {
    // Hardhat Account #0 (deployer)
    uint256 constant DEPLOYER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    // Faucet wallet (también Account #0 por ahora)
    address constant FAUCET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    // Token address (debe coincidir con el deployado)
    address constant ANDE_TOKEN = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    
    // Cantidad a mintear: 100 millones ANDE (suficiente para 200 requests de 500k)
    uint256 constant MINT_AMOUNT = 100_000_000 * 10**18;

    function run() external {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        console.log("=== Minting ANDE to Faucet ===");
        console.log("Token Address:", ANDE_TOKEN);
        console.log("Faucet Address:", FAUCET);
        
        TestToken andeToken = TestToken(ANDE_TOKEN);
        
        // Verificar balance actual
        uint256 currentBalance = andeToken.balanceOf(FAUCET);
        console.log("Current Faucet Balance:", currentBalance / 10**18, "ANDE");
        
        // Mintear tokens
        andeToken.mint(FAUCET, MINT_AMOUNT);
        console.log("Minted:", MINT_AMOUNT / 10**18, "ANDE");
        
        // Verificar nuevo balance
        uint256 newBalance = andeToken.balanceOf(FAUCET);
        console.log("New Faucet Balance:", newBalance / 10**18, "ANDE");
        console.log("Faucet can serve:", newBalance / (500_000 * 10**18), "requests of 500k ANDE");

        vm.stopBroadcast();
    }
}