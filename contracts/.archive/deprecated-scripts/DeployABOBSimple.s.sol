// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {AuctionManager} from "../src/AuctionManager.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

/**
 * @title DeployABOBSimple
 * @notice Script simplificado para desplegar solo el ecosistema ABOB CDP esencial
 */
contract DeployABOBSimple is Script {
    // Mock addresses for testing
    address constant USDC = 0xa0B86a33e6441B0E5c6a5D2D5f4D2d1B1e9e9E9E;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Deployed contracts
    AbobToken public abobToken;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    AuctionManager public auctionManager;
    ERC20Mock public usdcToken;
    ERC20Mock public wethToken;

    function run() external {
        vm.startBroadcast();

        console.log("=== TEST COMPLETED ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        // 1. Deploy Mock Tokens for testing
        _deployMockTokens();

        // 2. Deploy Core Infrastructure
        _deployInfrastructure();

        // 3. Initialize System
        _initializeSystem();

        // 4. Setup Initial Collateral
        _setupCollateral();

        vm.stopBroadcast();

        console.log("=== TEST COMPLETED ===");
        _logAddresses();
    }

    function _deployMockTokens() internal {
        console.log("=== TEST COMPLETED ===");

        // Deploy Mock USDC
        usdcToken = new ERC20Mock("USD Coin", "USDC");
        console.log("Mock USDC deployed at:", address(usdcToken));

        // Deploy Mock WETH
        wethToken = new ERC20Mock("Wrapped Ether", "WETH");
        console.log("Mock WETH deployed at:", address(wethToken));
    }

    function _deployInfrastructure() internal {
        console.log("=== TEST COMPLETED ===");

        // Deploy Price Oracle
        priceOracle = new PriceOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(priceOracle),
            abi.encodeWithSelector(PriceOracle.initialize.selector)
        );
        priceOracle = PriceOracle(address(oracleProxy));
        console.log("PriceOracle deployed at:", address(priceOracle));

        // Deploy Collateral Manager
        collateralManager = new CollateralManager();
        ERC1967Proxy collateralProxy = new ERC1967Proxy(
            address(collateralManager),
            abi.encodeWithSelector(
                CollateralManager.initialize.selector,
                msg.sender, // owner
                address(priceOracle) // default oracle
            )
        );
        collateralManager = CollateralManager(address(collateralProxy));
        console.log("CollateralManager deployed at:", address(collateralManager));

        // Deploy ABOB Token
        abobToken = new AbobToken();
        ERC1967Proxy abobProxy = new ERC1967Proxy(
            address(abobToken),
            abi.encodeWithSelector(
                AbobToken.initialize.selector,
                msg.sender, // admin
                msg.sender, // pauser
                msg.sender, // governance
                address(priceOracle), // price oracle
                address(collateralManager), // collateral manager
                address(auctionManager) // liquidation manager (will be set later)
            )
        );
        abobToken = AbobToken(payable(address(abobProxy)));
        console.log("AbobToken deployed at:", address(abobToken));

        // Deploy Auction Manager
        auctionManager = new AuctionManager();
        ERC1967Proxy auctionProxy = new ERC1967Proxy(
            address(auctionManager),
            abi.encodeWithSelector(
                AuctionManager.initialize.selector,
                msg.sender, // owner
                address(abobToken), // ABOB token
                address(collateralManager) // collateral manager
            )
        );
        auctionManager = AuctionManager(address(auctionProxy));
        console.log("AuctionManager deployed at:", address(auctionManager));
    }

    function _initializeSystem() internal {
        console.log("=== TEST COMPLETED ===");

        // Set auction manager as liquidation manager in ABOB token
        abobToken.grantRole(abobToken.LIQUIDATION_MANAGER_ROLE(), address(auctionManager));

        console.log("System initialized successfully");
    }

    function _setupCollateral() internal {
        console.log("=== TEST COMPLETED ===");

        // Add USDC as collateral
        collateralManager.addCollateral(
            address(usdcToken),
            15000, // 150% over-collateralization
            12500, // 125% liquidation threshold
            1_000_000 * 1e6, // 1M USDC debt ceiling
            100 * 1e6, // 100 USDC minimum deposit
            address(priceOracle)
        );

        // Add WETH as collateral
        collateralManager.addCollateral(
            address(wethToken),
            16000, // 160% over-collateralization
            13000, // 130% liquidation threshold
            1000 * 1e18, // 1000 WETH debt ceiling
            1 * 1e17, // 0.1 WETH minimum deposit
            address(priceOracle)
        );

        // Add supported collaterals to ABOB token (backwards compatibility)
        abobToken.addSupportedCollateral(address(usdcToken));
        abobToken.addSupportedCollateral(address(wethToken));

        console.log("USDC and WETH added as collateral");
    }

    function _logAddresses() internal view {
        console.log("=== TEST COMPLETED ===");
        console.log("Mock USDC:", address(usdcToken));
        console.log("Mock WETH:", address(wethToken));
        console.log("ABOB Token:", address(abobToken));
        console.log("Price Oracle:", address(priceOracle));
        console.log("Collateral Manager:", address(collateralManager));
        console.log("Auction Manager:", address(auctionManager));
    }
}