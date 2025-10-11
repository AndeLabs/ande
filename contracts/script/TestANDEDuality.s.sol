// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";

contract TestANDEDuality is Script {
    address public constant ANDE_PRECOMPILE = 0x00000000000000000000000000000000000000fd;

    // Deployer address for testing
    address public constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Testing ANDE Token Duality ===");
        console.log("Deployer address:", DEPLOYER);
        console.log("ANDE Precompile address:", ANDE_PRECOMPILE);

        // Test 1: Check if precompile exists
        uint256 precompileSize = ANDE_PRECOMPILE.code.length;
        console.log("Precompile bytecode size:", precompileSize);

        // Test 2: Check deployer balance before
        uint256 initialBalance = DEPLOYER.balance;
        console.log("Initial balance:", initialBalance);

        // Test 3: Deploy a simple contract that accepts payments
        SimpleContract simpleContract = new SimpleContract();
        console.log("Simple contract deployed to:", address(simpleContract));

        // Test 4: Send 100 wei to test contract
        (bool transferSuccess, ) = address(simpleContract).call{value: 100}("");
        console.log("Transfer to simple contract success:", transferSuccess);

        // Test 5: Check deployer balance after transfer
        uint256 finalBalance = DEPLOYER.balance;
        console.log("Final balance after transfer:", finalBalance);

        // Test 6: Check contract received balance
        uint256 contractBalance = address(simpleContract).balance;
        console.log("Contract balance received:", contractBalance);

        // Test 7: Calculate gas used
        uint256 gasUsed = initialBalance - finalBalance;
        console.log("Gas used for transaction (including value):", gasUsed);

        // Test 8: Try to call precompile (should fail gracefully if not implemented)
        (bool precompileCallSuccess, ) = ANDE_PRECOMPILE.call{value: 0}("");
        console.log("Precompile call success:", precompileCallSuccess);

        vm.stopBroadcast();
    }
}

contract SimpleContract {
    receive() external payable {
        // This will be called when ANDE is sent to this contract
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}