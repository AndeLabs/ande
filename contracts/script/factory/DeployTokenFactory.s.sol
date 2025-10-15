// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AndeTokenFactory} from "../../src/factory/AndeTokenFactory.sol";

contract DeployTokenFactory is Script {
    AndeTokenFactory public factory;
    
    address public owner;
    address public feeRecipient;
    uint256 public creationFee;
    
    function setUp() public {
        owner = msg.sender;
        feeRecipient = msg.sender; // Can be changed later
        creationFee = 0.01 ether; // 0.01 ANDE
    }
    
    function run() public virtual {
        vm.startBroadcast();
        
        // Deploy factory
        // TODO: Update with actual addresses
        factory = new AndeTokenFactory(
            address(0), // andeSwapFactory - update with actual
            address(0), // andeSwapRouter - update with actual  
            address(0), // andeToken - update with actual
            feeRecipient
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Token Factory Deployment Summary ===");
        console.log("Factory:", address(factory));
        console.log("Owner:", owner);
        console.log("Fee Recipient:", feeRecipient);
        console.log("Creation Fee:", creationFee, "ANDE");
        console.log("=======================================\n");
        
        // Verify deployment
        _verifyDeployment();
    }
    
    function _verifyDeployment() internal view {
        require(address(factory) != address(0), "Factory deployment failed");
        require(factory.owner() == owner, "Factory owner not set correctly");
        require(factory.feeRecipient() == feeRecipient, "Factory feeRecipient not set correctly");
        require(factory.creationFee() == creationFee, "Factory creationFee not set correctly");
        
        console.log("OK - All deployment verifications passed!");
    }
    
    function updateFeeRecipient(address newFeeRecipient) public {
        require(address(factory) != address(0), "Factory not deployed");
        
        vm.startBroadcast();
        
        factory.setFeeRecipient(newFeeRecipient);
        
        console.log("Fee recipient updated to:", newFeeRecipient);
        
        vm.stopBroadcast();
    }
    
    function updateCreationFee(uint256 newFee) public {
        require(address(factory) != address(0), "Factory not deployed");
        
        vm.startBroadcast();
        
        factory.setCreationFee(newFee);
        
        console.log("Creation fee updated to:", newFee, "ANDE");
        
        vm.stopBroadcast();
    }
    
    function withdrawFees() public {
        require(address(factory) != address(0), "Factory not deployed");
        
        vm.startBroadcast();
        
        factory.withdrawFees();
        
        console.log("Fees withdrawn to:", factory.feeRecipient());
        
        vm.stopBroadcast();
    }
}

contract DeployTokenFactoryWithConfig is DeployTokenFactory {
    struct FactoryConfig {
        address owner;
        address feeRecipient;
        uint256 creationFee;
    }
    
    function deployWithConfig(FactoryConfig memory config) public {
        owner = config.owner;
        feeRecipient = config.feeRecipient;
        creationFee = config.creationFee;
        
        vm.startBroadcast();
        
        // Deploy factory with custom config
        factory = new AndeTokenFactory(address(0), address(0), address(0), config.feeRecipient);
        
        // Update creation fee if different from default
        if (config.creationFee != 0.01 ether) {
            factory.setCreationFee(config.creationFee);
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== Token Factory Custom Deployment ===");
        console.log("Factory:", address(factory));
        console.log("Owner:", config.owner);
        console.log("Fee Recipient:", config.feeRecipient);
        console.log("Creation Fee:", config.creationFee, "ANDE");
        console.log("======================================\n");
    }
}

contract DeployTokenFactoryTestnet is DeployTokenFactory {
    function run() public override {
        // Testnet configuration
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default hardhat account
        feeRecipient = owner;
        creationFee = 0.001 ether; // Lower fee for testnet
        
        super.run();
        
        console.log("\nTEST: Testnet Token Factory deployment complete!");
        console.log("Ready for testing on local network");
    }
}

contract DeployTokenFactoryMainnet is DeployTokenFactory {
    function run() public override {
        // Mainnet configuration
        owner = msg.sender; // Should be a multisig or DAO
        feeRecipient = msg.sender; // Should be treasury contract
        creationFee = 0.01 ether; // 0.01 ANDE - $0.10 at $10/ANDE
        
        super.run();
        
        console.log("\nOK Mainnet Token Factory deployment complete!");
        console.log("IMPORTANT: Verify all contracts on Etherscan");
        console.log("IMPORTANT: Transfer ownership to multisig/DAO");
        console.log("IMPORTANT: Set up proper fee collection to treasury");
    }
}

contract CreateSampleTokens is DeployTokenFactory {
    function run() public override {
        // Deploy factory first if not already deployed
        if (address(factory) == address(0)) {
            DeployTokenFactory testnetFactory = new DeployTokenFactoryTestnet();
            testnetFactory.run();
            factory = testnetFactory.factory();
        }
        
        vm.startBroadcast();
        
        // Create sample tokens with correct API
        address token1 = factory.createStandardToken{value: 0.001 ether}(
            "Sample Token One",
            "SAMPLE1",
            1000000 ether,
            true,  // autoList
            0      // initialLiquidity
        );
        
        address token2 = factory.createMintableToken{value: 0.001 ether}(
            "Sample Token Two",
            "SAMPLE2",
            500000 ether,   // initialSupply
            1000000 ether   // maxSupply
        );
        
        // Create tax config struct
        AndeTokenFactory.TaxConfig memory taxConfig = AndeTokenFactory.TaxConfig({
            buyTax: 200,           // 2% buy tax
            sellTax: 200,          // 2% sell tax
            taxRecipient: msg.sender,
            maxTx: 10000 ether,    // Max transaction
            maxWallet: 50000 ether // Max wallet
        });
        
        address token3 = factory.createTaxableToken{value: 0.001 ether}(
            "Sample Token Three",
            "SAMPLE3",
            1000000 ether,
            taxConfig
        );
        
        address token4 = factory.createReflectionToken{value: 0.001 ether}(
            "Sample Token Four",
            "SAMPLE4",
            2000000 ether,
            100    // 1% reflection fee (in basis points, so 100 = 1%)
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Sample Tokens Created ===");
        console.log("Standard Token:", token1);
        console.log("Mintable Token:", token2);
        console.log("Taxable Token:", token3);
        console.log("Reflection Token:", token4);
        console.log("============================\n");
    }
}

contract BatchTokenCreation is DeployTokenFactory {
    struct TokenConfig {
        string name;
        string symbol;
        uint256 supply;
        uint256 tokenType; // 0=Standard, 1=Mintable, 2=Burnable, 3=Taxable, 4=Reflection
        uint256 taxRate; // For taxable tokens
        address taxRecipient; // For taxable tokens
        uint256 reflectionFee; // For reflection tokens
    }
    
    function createBatch(TokenConfig[] memory configs) public {
        // Deploy factory first if not already deployed
        if (address(factory) == address(0)) {
            DeployTokenFactory testnetFactory = new DeployTokenFactoryTestnet();
            testnetFactory.run();
            factory = testnetFactory.factory();
        }
        
        vm.startBroadcast();
        
        address[] memory createdTokens = new address[](configs.length);
        
        for (uint256 i = 0; i < configs.length; i++) {
            TokenConfig memory config = configs[i];
            
            if (config.tokenType == 0) {
                createdTokens[i] = factory.createStandardToken{value: 0.001 ether}(
                    config.name,
                    config.symbol,
                    config.supply,
                    true,  // autoList
                    0      // initialLiquidity
                );
            } else if (config.tokenType == 1) {
                createdTokens[i] = factory.createMintableToken{value: 0.001 ether}(
                    config.name,
                    config.symbol,
                    config.supply,
                    config.supply * 2  // maxSupply = 2x initial
                );
            } else if (config.tokenType == 3) {
                AndeTokenFactory.TaxConfig memory taxCfg = AndeTokenFactory.TaxConfig({
                    buyTax: config.taxRate,
                    sellTax: config.taxRate,
                    taxRecipient: config.taxRecipient,
                    maxTx: config.supply / 100,    // 1% of supply
                    maxWallet: config.supply / 50  // 2% of supply
                });
                createdTokens[i] = factory.createTaxableToken{value: 0.001 ether}(
                    config.name,
                    config.symbol,
                    config.supply,
                    taxCfg
                );
            } else if (config.tokenType == 4) {
                createdTokens[i] = factory.createReflectionToken{value: 0.001 ether}(
                    config.name,
                    config.symbol,
                    config.supply,
                    config.reflectionFee
                );
            }
            
            console.log(string(abi.encodePacked(
                "Created ", 
                _tokenTypeName(config.tokenType), 
                " token: ", 
                config.name, 
                " (", 
                config.symbol, 
                ") at ", 
        vm.toString(createdTokens[i])
            )));
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== Batch Token Creation Complete ===");
        console.log("Total Tokens Created:", configs.length);
        // console.log("Factory Total Count:", factory.tokensCreated());
        console.log("=====================================\n");
        
        // Return token addresses for further use
        _storeTokenAddresses(createdTokens);
    }
    
    function _tokenTypeName(uint256 tokenType) internal pure returns (string memory) {
        if (tokenType == 0) return "Standard";
        if (tokenType == 1) return "Mintable";
        if (tokenType == 2) return "Burnable";
        if (tokenType == 3) return "Taxable";
        if (tokenType == 4) return "Reflection";
        return "Unknown";
    }
    
    function _storeTokenAddresses(address[] memory tokens) internal {
        // This would typically store the addresses in a mapping or emit events
        // For now, just log them
        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("Token", i, ":", tokens[i]);
        }
    }
}