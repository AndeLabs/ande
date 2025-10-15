// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";
import {AndeSwapRouter} from "../../src/dex/AndeSwapRouter.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

contract DeployAndeSwap is Script {
    AndeSwapFactory public factory;
    AndeSwapRouter public router;
    ERC20Mock public ande;
    
    address public owner;
    address public feeToSetter;
    
    function setUp() public {
        owner = msg.sender;
        feeToSetter = msg.sender; // Can be changed later
        
        // If ANDE doesn't exist, deploy mock for testing
        ande = new ERC20Mock("ANDE", "ANDE");
        ande.mint(msg.sender, 1000000 ether);
    }
    
    function run() public virtual {
        vm.startBroadcast();
        
        // Deploy factory
        factory = new AndeSwapFactory(feeToSetter);
        console.log("AndeSwapFactory deployed to:", address(factory));
        
        // Deploy router
        router = new AndeSwapRouter(address(factory));
        console.log("AndeSwapRouter deployed to:", address(router));
        
        // Deploy ANDE token if needed
        console.log("ANDE Token deployed to:", address(ande));
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== AndeSwap Deployment Summary ===");
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("ANDE Token:", address(ande));
        console.log("Owner:", owner);
        console.log("Fee To Setter:", feeToSetter);
        console.log("=====================================\n");
        
        // Verify deployment
        _verifyDeployment();
    }
    
    function _verifyDeployment() internal view {
        require(address(factory) != address(0), "Factory deployment failed");
        require(address(router) != address(0), "Router deployment failed");
        require(address(ande) != address(0), "ANDE token deployment failed");
        
        require(factory.feeToSetter() == feeToSetter, "Factory feeToSetter not set correctly");
        require(address(router.factory()) == address(factory), "Router factory not set correctly");
        require(router.ANDE() == address(ande), "Router WETH not set correctly");
        
        console.log("OK - All deployment verifications passed!");
    }
    
    function createInitialLiquidity() public {
        require(address(factory) != address(0), "Factory not deployed");
        require(address(router) != address(0), "Router not deployed");
        
        vm.startBroadcast();
        
        // Create some initial pairs for testing
        address pair1 = factory.createPair(address(ande), address(0x1234567890123456789012345678901234567890));
        address pair2 = factory.createPair(address(ande), address(0x2345678901234567890123456789012345678901));
        
        console.log("Created initial pairs:");
        console.log("Pair 1:", pair1);
        console.log("Pair 2:", pair2);
        
        vm.stopBroadcast();
    }
    
    function setFeeTo(address feeTo) public {
        require(address(factory) != address(0), "Factory not deployed");
        
        vm.startBroadcast();
        
        factory.setFeeTo(feeTo);
        
        console.log("FeeTo set to:", feeTo);
        
        vm.stopBroadcast();
    }
}

contract DeployAndeSwapWithConfig is DeployAndeSwap {
    struct DeployConfig {
        address owner;
        address feeToSetter;
        address feeTo;
        uint256 andeSupply;
        string andeName;
        string andeSymbol;
    }
    
    function deployWithConfig(DeployConfig memory config) public {
        owner = config.owner;
        feeToSetter = config.feeToSetter;
        
        vm.startBroadcast();
        
        // Deploy ANDE with custom config
        ande = new ERC20Mock(config.andeName, config.andeSymbol);
        ande.mint(msg.sender, config.andeSupply);
        
        // Deploy factory
        factory = new AndeSwapFactory(config.feeToSetter);
        
        // Deploy router
        router = new AndeSwapRouter(address(factory));
        
        // Set feeTo if provided
        if (config.feeTo != address(0)) {
            factory.setFeeTo(config.feeTo);
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== AndeSwap Custom Deployment ===");
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("ANDE Token:", address(ande));
        console.log("ANDE Name:", config.andeName);
        console.log("ANDE Symbol:", config.andeSymbol);
        console.log("ANDE Supply:", config.andeSupply);
        console.log("Owner:", config.owner);
        console.log("Fee To Setter:", config.feeToSetter);
        console.log("Fee To:", config.feeTo);
        console.log("===================================\n");
    }
}

contract DeployAndeSwapTestnet is DeployAndeSwap {
    function run() public override {
        // Testnet configuration
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default hardhat account
        feeToSetter = owner;
        
        super.run();
        
        // Create test pairs
        createInitialLiquidity();
        
        console.log("\nTEST: Testnet deployment complete!");
        console.log("Ready for testing on local network");
    }
}

contract DeployAndeSwapMainnet is DeployAndeSwap {
    function run() public override {
        // Mainnet configuration - these should be set properly for mainnet deployment
        owner = msg.sender; // Should be a multisig or DAO
        feeToSetter = msg.sender; // Should be a governance contract
        
        super.run();
        
        console.log("\nOK Mainnet deployment complete!");
        console.log("IMPORTANT: Verify all contracts on Etherscan");
        console.log("IMPORTANT: Transfer ownership to multisig/DAO");
        console.log("IMPORTANT: Set up proper fee collection");
    }
}