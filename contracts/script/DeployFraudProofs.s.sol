// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AndeDisputeGameFactory} from "../src/fraud-proofs/AndeDisputeGameFactory.sol";
import {AndeFaultGame} from "../src/fraud-proofs/AndeFaultGame.sol";

/**
 * @title DeployFraudProofs
 * @notice Deployment script for fraud proof system
 */
contract DeployFraudProofs is Script {
    // Configuration
    uint256 public constant BOND_AMOUNT = 0.1 ether;          // Initial bond for creating games
    uint256 public constant MAX_GAME_DURATION = 7 days;        // Maximum game duration
    uint64 public constant CHESS_CLOCK_DURATION = 3.5 days;    // Per-player time allocation
    uint64 public constant GLOBAL_DURATION = 7 days;           // Total game duration
    uint256 public constant MIN_BOND = 0.1 ether;              // Minimum bond
    uint256 public constant MAX_BOND = 100 ether;              // Maximum bond

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying fraud proof system...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AndeFaultGame implementation
        console.log("\n1. Deploying AndeFaultGame implementation...");
        AndeFaultGame faultGameImpl = new AndeFaultGame();
        console.log("AndeFaultGame implementation deployed at:", address(faultGameImpl));

        // 2. Deploy AndeDisputeGameFactory
        console.log("\n2. Deploying AndeDisputeGameFactory...");
        AndeDisputeGameFactory factory = new AndeDisputeGameFactory(
            deployer,           // Owner
            BOND_AMOUNT,        // Bond amount
            MAX_GAME_DURATION   // Max game duration
        );
        console.log("AndeDisputeGameFactory deployed at:", address(factory));

        // 3. Register game implementations
        console.log("\n3. Registering game implementations...");
        
        // Register FAULT_CANNON
        factory.setGameImplementation(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            address(faultGameImpl)
        );
        console.log("Registered FAULT_CANNON implementation");

        // Register FAULT_ASTERISC (using same implementation for now)
        factory.setGameImplementation(
            AndeDisputeGameFactory.GameType.FAULT_ASTERISC,
            address(faultGameImpl)
        );
        console.log("Registered FAULT_ASTERISC implementation");

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Factory Address:", address(factory));
        console.log("FaultGame Implementation:", address(faultGameImpl));
        console.log("Bond Amount:", BOND_AMOUNT);
        console.log("Max Game Duration:", MAX_GAME_DURATION);
        console.log("\nTo verify contracts:");
        console.log("forge verify-contract", address(factory), "AndeDisputeGameFactory --watch");
        console.log("forge verify-contract", address(faultGameImpl), "AndeFaultGame --watch");
        
        // Save deployment addresses
        _saveDeployment(address(factory), address(faultGameImpl));
    }

    /**
     * @notice Saves deployment addresses to file
     */
    function _saveDeployment(address factory, address implementation) internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "factory": "', _addressToString(factory), '",\n',
            '  "faultGameImplementation": "', _addressToString(implementation), '",\n',
            '  "bondAmount": "', _uint256ToString(BOND_AMOUNT), '",\n',
            '  "maxGameDuration": "', _uint256ToString(MAX_GAME_DURATION), '",\n',
            '  "chessClockDuration": "', _uint256ToString(CHESS_CLOCK_DURATION), '",\n',
            '  "globalDuration": "', _uint256ToString(GLOBAL_DURATION), '",\n',
            '  "minBond": "', _uint256ToString(MIN_BOND), '",\n',
            '  "maxBond": "', _uint256ToString(MAX_BOND), '",\n',
            '  "deployedAt": "', _uint256ToString(block.timestamp), '"\n',
            '}'
        ));

        vm.writeFile("deployments/fraud-proofs.json", json);
        console.log("\nDeployment info saved to: deployments/fraud-proofs.json");
    }

    /**
     * @notice Converts address to string
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint8(data[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }

    /**
     * @notice Converts uint256 to string
     */
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
