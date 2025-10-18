// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AndeNativeStaking} from "../src/staking/AndeNativeStaking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployStaking
 * @notice Script para desplegar AndeNativeStaking con proxy UUPS
 * @dev Despliega implementation + proxy y configura roles iniciales
 *
 * Usage:
 *   forge script script/DeployStaking.s.sol:DeployStaking --rpc-url $RPC_URL --broadcast
 *   
 * Local:
 *   forge script script/DeployStaking.s.sol:DeployStaking --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY
 */
contract DeployStaking is Script {
    // Direcciones conocidas (actualizar según tu deployment)
    // ANDETokenDuality Proxy Address (Production)
    address constant ANDE_TOKEN_ADDRESS = 0x7a2088a1bFc9d81c55368AE168C2C02570cB814F;
    
    // Roles
    address public admin;
    address public rewardDistributor;
    address public sequencerManager;
    address public pauser;

    function setUp() public {
        // En producción, estos deberían ser diferentes addresses
        admin = msg.sender;
        rewardDistributor = msg.sender;
        sequencerManager = msg.sender;
        pauser = msg.sender;
    }

    function run() public {
        // Validar que ANDE token existe
        require(ANDE_TOKEN_ADDRESS != address(0), "ANDE token address not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("==============================================");
        console2.log("Deploying AndeNativeStaking");
        console2.log("==============================================");
        console2.log("Deployer:", deployer);
        console2.log("ANDE Token:", ANDE_TOKEN_ADDRESS);
        console2.log("Admin:", admin);
        console2.log("==============================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation
        AndeNativeStaking implementation = new AndeNativeStaking();
        console2.log("Implementation deployed at:", address(implementation));

        // 2. Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            ANDE_TOKEN_ADDRESS,
            admin,
            rewardDistributor,
            sequencerManager,
            pauser
        );

        // 3. Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console2.log("Proxy deployed at:", address(proxy));

        // 4. Verify initialization
        AndeNativeStaking staking = AndeNativeStaking(payable(address(proxy)));
        
        console2.log("==============================================");
        console2.log("Deployment Summary");
        console2.log("==============================================");
        console2.log("AndeNativeStaking Implementation:", address(implementation));
        console2.log("AndeNativeStaking Proxy:", address(proxy));
        console2.log("ANDE Token:", address(staking.andeToken()));
        console2.log("MIN_LIQUIDITY_STAKE:", staking.MIN_LIQUIDITY_STAKE() / 1e18, "ANDE");
        console2.log("MIN_GOVERNANCE_STAKE:", staking.MIN_GOVERNANCE_STAKE() / 1e18, "ANDE");
        console2.log("MIN_SEQUENCER_STAKE:", staking.MIN_SEQUENCER_STAKE() / 1e18, "ANDE");
        console2.log("==============================================");
        
        // Log for frontend integration
        console2.log("");
        console2.log("Add to andefrontend/src/contracts/addresses.ts:");
        console2.log("AndeNativeStaking: '%s' as Address,", address(proxy));
        console2.log("");

        vm.stopBroadcast();

        // Save deployment info
        _saveDeployment(address(implementation), address(proxy));
    }

    function _saveDeployment(address implementation, address proxy) internal {
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "implementation": "', vm.toString(implementation), '",\n',
                '  "proxy": "', vm.toString(proxy), '",\n',
                '  "andeToken": "', vm.toString(ANDE_TOKEN_ADDRESS), '",\n',
                '  "admin": "', vm.toString(admin), '",\n',
                '  "deployer": "', vm.toString(msg.sender), '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '",\n',
                '  "blockNumber": "', vm.toString(block.number), '"\n',
                "}\n"
            )
        );

        vm.writeFile("deployments/staking-latest.json", deploymentInfo);
        console2.log("Deployment info saved to deployments/staking-latest.json");
    }
}

/**
 * @title DeployStakingLocal
 * @notice Script simplificado para deployment local
 */
contract DeployStakingLocal is Script {
    // ANDETokenDuality Proxy Address (Production)
    address constant ANDE_TOKEN_ADDRESS = 0x7a2088a1bFc9d81c55368AE168C2C02570cB814F;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying AndeNativeStaking (Local)...");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        AndeNativeStaking implementation = new AndeNativeStaking();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            AndeNativeStaking.initialize.selector,
            ANDE_TOKEN_ADDRESS,
            deployer, // admin
            deployer, // rewardDistributor
            deployer, // sequencerManager
            deployer  // pauser
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console2.log("====================================");
        console2.log("AndeNativeStaking deployed!");
        console2.log("Proxy:", address(proxy));
        console2.log("Implementation:", address(implementation));
        console2.log("====================================");
        console2.log("");
        console2.log("Update addresses.ts with:");
        console2.log("AndeNativeStaking: '%s' as Address,", address(proxy));

        vm.stopBroadcast();
    }
}