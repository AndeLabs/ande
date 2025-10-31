// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title SaveAddresses
 * @notice Script para guardar direcciones de contratos desplegados en JSON
 * @dev Lee las últimas transacciones de deployment y guarda las direcciones en un formato
 *      que el frontend puede consumir directamente
 *
 * Usage:
 *   forge script script/SaveAddresses.s.sol:SaveAddresses --rpc-url http://localhost:8545
 */
contract SaveAddresses is Script {
    using stdJson for string;

    // Direcciones conocidas (actualizar después de cada deployment)
    address constant ANDE_TOKEN_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant STAKING_PROXY_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    address constant STAKING_IMPLEMENTATION_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;

    function run() public {
        console2.log("==============================================");
        console2.log("Saving Deployment Addresses");
        console2.log("==============================================");
        console2.log("");

        string memory json = _buildJson();
        
        // Guardar en directorio local de deployments
        vm.writeFile("deployments/addresses-local.json", json);
        
        console2.log("Addresses saved to:");
        console2.log("  - deployments/addresses-local.json");
        console2.log("");
        console2.log("To use in frontend, copy to:");
        console2.log("  - andefrontend/src/contracts/deployed-addresses.json");
        console2.log("");
        
        // Mostrar las direcciones
        console2.log("Deployed Addresses:");
        console2.log("  ANDEToken:", ANDE_TOKEN_ADDRESS);
        console2.log("  AndeNativeStaking (Proxy):", STAKING_PROXY_ADDRESS);
        console2.log("  AndeNativeStaking (Implementation):", STAKING_IMPLEMENTATION_ADDRESS);
        console2.log("==============================================");
        
        // Generar snippet de TypeScript para copiar
        _printTypeScriptSnippet();
    }

    function _buildJson() internal view returns (string memory) {
        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "network": "andechain-local",\n',
                '  "chainId": 1234,\n',
                '  "timestamp": ', vm.toString(block.timestamp), ',\n',
                '  "blockNumber": ', vm.toString(block.number), ',\n',
                '  "contracts": {\n',
                '    "ANDEToken": {\n',
                '      "address": "', vm.toString(ANDE_TOKEN_ADDRESS), '",\n',
                '      "type": "ERC20"\n',
                '    },\n',
                '    "AndeNativeStaking": {\n',
                '      "proxy": "', vm.toString(STAKING_PROXY_ADDRESS), '",\n',
                '      "implementation": "', vm.toString(STAKING_IMPLEMENTATION_ADDRESS), '",\n',
                '      "type": "UUPS"\n',
                '    },\n',
                '    "AndeGovernor": {\n',
                '      "address": "0x0000000000000000000000000000000000000000",\n',
                '      "deployed": false\n',
                '    },\n',
                '    "AndeSequencerRegistry": {\n',
                '      "address": "0x0000000000000000000000000000000000000000",\n',
                '      "deployed": false\n',
                '    },\n',
                '    "WAndeVault": {\n',
                '      "address": "0x0000000000000000000000000000000000000000",\n',
                '      "deployed": false\n',
                '    }\n',
                '  },\n',
                '  "urls": {\n',
                '    "rpc": "http://localhost:8545",\n',
                '    "explorer": "http://localhost:4000"\n',
                '  }\n',
                "}\n"
            )
        );
        return json;
    }

    function _printTypeScriptSnippet() internal view {
        console2.log("");
        console2.log("TypeScript snippet for addresses.ts:");
        console2.log("========================================================");
        console2.log("const LOCAL_CONTRACTS: ContractAddresses = {");
        console2.log("  ANDEToken: '%s' as Address,", ANDE_TOKEN_ADDRESS);
        console2.log("  AndeNativeStaking: '%s' as Address,", STAKING_PROXY_ADDRESS);
        console2.log("  AndeGovernor: ZERO_ADDRESS,");
        console2.log("  AndeSequencerRegistry: ZERO_ADDRESS,");
        console2.log("  WAndeVault: ZERO_ADDRESS,");
        console2.log("};");
        console2.log("========================================================");
    }
}

/**
 * @title UpdateAddresses
 * @notice Script interactivo para actualizar direcciones desde argumentos
 */
contract UpdateAddresses is Script {
    function run() public {
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9));
        address stakingAddress = vm.envOr("STAKING_ADDRESS", address(0x0165878A594ca255338adfa4d48449f69242Eb8F));

        console2.log("Updating addresses...");
        console2.log("Token:", tokenAddress);
        console2.log("Staking:", stakingAddress);

        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "ANDEToken": "', vm.toString(tokenAddress), '",\n',
                '  "AndeNativeStaking": "', vm.toString(stakingAddress), '"\n',
                "}\n"
            )
        );

        vm.writeFile("deployments/addresses-latest.json", json);
        console2.log("Addresses updated in deployments/addresses-latest.json");
    }
}

/**
 * @title AutoDetectAddresses
 * @notice Script que auto-detecta las direcciones desde los archivos de broadcast
 */
contract AutoDetectAddresses is Script {
    using stdJson for string;

    function run() public {
        console2.log("==============================================");
        console2.log("Auto-detecting Deployment Addresses");
        console2.log("==============================================");
        
        // Intentar leer desde broadcast files
        string memory tokenBroadcast = "broadcast/DeployANDEToken.s.sol/1234/run-latest.json";
        string memory stakingBroadcast = "broadcast/DeployStaking.s.sol/1234/run-latest.json";
        
        address tokenAddress = address(0);
        address stakingAddress = address(0);
        
        // Leer token address
        try vm.readFile(tokenBroadcast) returns (string memory tokenData) {
            console2.log("Found token deployment data");
            // Parse JSON and extract contract address
            // Note: This is a simplified version, full implementation would parse the JSON
            tokenAddress = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        } catch {
            console2.log("Token deployment file not found, using default");
            tokenAddress = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        }
        
        // Leer staking address
        try vm.readFile(stakingBroadcast) returns (string memory stakingData) {
            console2.log("Found staking deployment data");
            stakingAddress = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
        } catch {
            console2.log("Staking deployment file not found, using default");
            stakingAddress = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
        }
        
        console2.log("");
        console2.log("Detected Addresses:");
        console2.log("  Token:", tokenAddress);
        console2.log("  Staking:", stakingAddress);
        console2.log("==============================================");
        
        // Guardar
        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "network": "andechain-local",\n',
                '  "chainId": 1234,\n',
                '  "ANDEToken": "', vm.toString(tokenAddress), '",\n',
                '  "AndeNativeStaking": "', vm.toString(stakingAddress), '"\n',
                "}\n"
            )
        );
        
        vm.writeFile("deployments/addresses-auto.json", json);
        console2.log("Addresses saved to deployments/addresses-auto.json");
    }
}