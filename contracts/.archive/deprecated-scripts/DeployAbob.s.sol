// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {AuctionManager} from "../src/AuctionManager.sol";
import {sAbobToken} from "../src/sAbobToken.sol";
import {AndeGovernor} from "../src/governance/AndeGovernor.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";
import {VotingEscrow} from "../src/gauges/VotingEscrow.sol";

/**
 * @title DeployABOB
 * @notice Script para desplegar el ecosistema ABOB CDP (Collateralized Debt Position)
 * @dev Este script despliega todos los contratos principales del sistema ABOB
 */
contract DeployABOB is Script {
    // ==================== CONFIGURATION ====================
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xa0B86a33e6441B0E5c6a5D2D5f4D2d1B1e9e9E9E;
    address constant ANDE_CHAINLINK_FEED = 0x1234567890123456789012345678901234567890;
    address constant USDC_CHAINLINK_FEED = 0x1234567890123456789012345678901234567891;
    address constant WETH_CHAINLINK_FEED = 0x1234567890123456789012345678901234567892;

    // Default deployment addresses (will be overridden by PRIVATE_KEY)
    address private deployer;
    address private timelock;
    address private governor;

    // ==================== DEPLOYED CONTRACTS ====================
    ANDEToken public andeToken;
    AbobToken public abobToken;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    AuctionManager public auctionManager;
    sAbobToken public sAbobTokenContract;
    VotingEscrow public votingEscrow;
    AndeGovernor public andeGovernor;
    AndeTimelockController public andeTimelock;

    // ==================== RUN FUNCTION ====================
    function run() external {
        vm.startBroadcast();

        deployer = msg.sender;

        console.log("=== TEST COMPLETED ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        // 1. Deploy Core Token Contracts first (needed for governance)
        _deployTokens();

        // 2. Deploy Timelock Controller (central point of control)
        _deployTimelock();

        // 3. Deploy Governance Contracts
        _deployGovernance();

        // 4. Deploy Infrastructure Contracts
        _deployInfrastructure();

        // 5. Initialize Ecosystem
        _initializeEcosystem();

        // 6. Setup Initial Collateral Types
        _setupCollateralTypes();

        // 7. Transfer Ownership to Governance
        _transferToGovernance();

        // 8. Save Deployment Info
        _saveDeploymentInfo();

        vm.stopBroadcast();

        console.log("=== TEST COMPLETED ===");
        _logDeploymentSummary();
    }

    // ==================== DEPLOYMENT FUNCTIONS ====================

    function _deployTimelock() internal {
        console.log("=== TEST COMPLETED ===");

        andeTimelock = new AndeTimelockController();
        timelock = address(andeTimelock);
        console.log("AndeTimelock deployed at:", timelock);
    }

    function _deployGovernance() internal {
        console.log("=== TEST COMPLETED ===");

        // Deploy VotingEscrow (veANDE) - direct deployment (no proxy)
        votingEscrow = new VotingEscrow(
            address(andeToken),
            "veANDE",
            "veANDE",
            "1.0.0"
        );
        console.log("VotingEscrow deployed at:", address(votingEscrow));

        // Deploy Governor
        andeGovernor = new AndeGovernor();
        governor = address(andeGovernor);
        console.log("AndeGovernor deployed at:", governor);
    }

    function _deployTokens() internal {
        console.log("=== TEST COMPLETED ===");

        // Deploy ANDE Token
        andeToken = new ANDEToken();
        ERC1967Proxy andeProxy = new ERC1967Proxy(
            address(andeToken),
            abi.encodeWithSelector(
                ANDEToken.initialize.selector,
                deployer,
                "Ande Token",
                "ANDE",
                timelock
            )
        );

        andeToken = ANDEToken(address(andeProxy));
        console.log("ANDEToken deployed at:", address(andeToken));

        // Deploy ABOB Token (CDP)
        abobToken = new AbobToken();
        ERC1967Proxy abobProxy = new ERC1967Proxy(
            address(abobToken),
            abi.encodeWithSelector(
                AbobToken.initialize.selector,
                timelock, // Default admin
                timelock, // Pauser
                timelock, // Governance
                address(0), // Price oracle (will be set after deployment)
                address(0), // Collateral manager (will be set after deployment)
                address(0)  // Liquidation manager (will be set after deployment)
            )
        );

        abobToken = AbobToken(payable(address(abobProxy)));
        console.log("AbobToken deployed at:", address(abobToken));

        // Deploy sABOB Token (Yield Vault)
        sAbobTokenContract = new sAbobToken();
        ERC1967Proxy sAbobProxy = new ERC1967Proxy(
            address(sAbobTokenContract),
            abi.encodeWithSelector(
                sAbobToken.initialize.selector,
                address(abobToken), // Underlying ABOB token
                timelock,
                "Staked ABOB",
                "sABOB"
            )
        );

        sAbobTokenContract = sAbobToken(address(sAbobProxy));
        console.log("sAbobToken deployed at:", address(sAbobTokenContract));
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
                timelock,
                address(priceOracle)
            )
        );

        collateralManager = CollateralManager(address(collateralProxy));
        console.log("CollateralManager deployed at:", address(collateralManager));

        // Deploy Auction Manager
        auctionManager = new AuctionManager();
        ERC1967Proxy auctionProxy = new ERC1967Proxy(
            address(auctionManager),
            abi.encodeWithSelector(
                AuctionManager.initialize.selector,
                timelock,
                address(abobToken),
                address(collateralManager)
            )
        );

        auctionManager = AuctionManager(address(auctionProxy));
        console.log("AuctionManager deployed at:", address(auctionManager));
    }

    function _initializeEcosystem() internal {
        console.log("=== TEST COMPLETED ===");

        // Initialize Timelock Controller only if not already initialized
        try andeTimelock.getMinDelay() returns (uint256) {
            console.log("Timelock already initialized");
        } catch {
            uint256 minDelay = 2 days; // 2 days delay for governance actions
            address[] memory proposers = new address[](1);
            address[] memory executors = new address[](1);
            proposers[0] = governor;
            executors[0] = address(0); // Anyone can execute
            andeTimelock.initialize(minDelay, proposers, executors, deployer);

            // Set up Timelock roles
            andeTimelock.grantRole(andeTimelock.PROPOSER_ROLE(), governor);
            andeTimelock.grantRole(andeTimelock.EXECUTOR_ROLE(), address(0));
            andeTimelock.grantRole(andeTimelock.CANCELLER_ROLE(), governor);
            console.log("Timelock initialized successfully");
        }

        // Grant roles to Auction Manager
        abobToken.grantRole(abobToken.LIQUIDATION_MANAGER_ROLE(), address(auctionManager));

        console.log("Ecosystem initialized");
    }

    function _setupCollateralTypes() internal {
        console.log("=== TEST COMPLETED ===");

        // Add price sources to Oracle
        priceOracle.addSource(USDC, USDC_CHAINLINK_FEED, "Chainlink USDC");
        priceOracle.addSource(WETH, WETH_CHAINLINK_FEED, "Chainlink WETH");
        priceOracle.addSource(address(andeToken), ANDE_CHAINLINK_FEED, "Chainlink ANDE");

        // Add USDC as collateral
        collateralManager.addCollateral(
            USDC,
            15000, // 150% over-collateralization ratio
            12500, // 125% liquidation threshold
            5_000_000 * 1e6, // 5M USDC debt ceiling
            100 * 1e6,      // 100 USDC minimum deposit
            address(priceOracle)
        );

        // Add WETH as collateral
        collateralManager.addCollateral(
            WETH,
            16000, // 160% over-collateralization ratio (more volatile)
            13000, // 130% liquidation threshold
            2_000 * 1e18,   // 2K WETH debt ceiling
            1 * 1e17,       // 0.1 WETH minimum deposit
            address(priceOracle)
        );

        // Add ANDE as collateral
        collateralManager.addCollateral(
            address(andeToken),
            20000, // 200% over-collateralization ratio (native token, higher risk)
            15000, // 150% liquidation threshold
            1_000_000 * 1e18, // 1M ANDE debt ceiling
            1000 * 1e18,      // 1000 ANDE minimum deposit
            address(priceOracle)
        );

        // Add supported collaterals to ABOB Token
        abobToken.addSupportedCollateral(USDC);
        abobToken.addSupportedCollateral(WETH);
        abobToken.addSupportedCollateral(address(andeToken));

        console.log("USDC added as collateral");
        console.log("WETH added as collateral");
        console.log("ANDE added as collateral");
    }

    function _transferToGovernance() internal {
        console.log("=== TEST COMPLETED ===");

        // Transfer ownership of contracts to Timelock
        andeToken.grantRole(andeToken.DEFAULT_ADMIN_ROLE(), timelock);
        abobToken.grantRole(abobToken.DEFAULT_ADMIN_ROLE(), timelock);
        sAbobTokenContract.grantRole(sAbobTokenContract.DEFAULT_ADMIN_ROLE(), timelock);
        priceOracle.transferOwnership(timelock);
        collateralManager.transferOwnership(timelock);
        auctionManager.transferOwnership(timelock);

        // Renounce deployer's role in Timelock
        andeTimelock.renounceRole(andeTimelock.DEFAULT_ADMIN_ROLE(), deployer);

        console.log("Ownership transferred to governance");
    }

    function _saveDeploymentInfo() internal {
        console.log("=== TEST COMPLETED ===");

        // Simple deployment info logging
        console.log("=== TEST COMPLETED ===");
        console.log("ANDEToken:", address(andeToken));
        console.log("AbobToken:", address(abobToken));
        console.log("sAbobToken:", address(sAbobTokenContract));
        console.log("PriceOracle:", address(priceOracle));
        console.log("CollateralManager:", address(collateralManager));
        console.log("AuctionManager:", address(auctionManager));
        console.log("VotingEscrow:", address(votingEscrow));
        console.log("AndeGovernor:", address(andeGovernor));
        console.log("AndeTimelock:", address(andeTimelock));

        console.log("Deployment info logged to console");
    }

    function _logDeploymentSummary() internal {
        console.log("=== TEST COMPLETED ===");
        console.log("Network:", block.chainid == 1 ? "Mainnet" : block.chainid == 31337 ? "Local" : vm.toString(block.chainid));
        console.log("Deployer:", deployer);
        console.log("");
        console.log("TOKENS:");
        console.log("  ANDE Token:", address(andeToken));
        console.log("  ABOB Token:", address(abobToken));
        console.log("  sABOB Token:", address(sAbobTokenContract));
        console.log("");
        console.log("INFRASTRUCTURE:");
        console.log("  Price Oracle:", address(priceOracle));
        console.log("  Collateral Manager:", address(collateralManager));
        console.log("  Auction Manager:", address(auctionManager));
        console.log("");
        console.log("GOVERNANCE:");
        console.log("  Voting Escrow:", address(votingEscrow));
        console.log("  Governor:", address(andeGovernor));
        console.log("  Timelock:", address(andeTimelock));
        console.log("");
        console.log("SUPPORTED COLLATERALS:");
        console.log("  USDC:", USDC);
        console.log("  WETH:", WETH);
        console.log("  ANDE:", address(andeToken));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Fund price oracle adapters with ETH");
        console.log("3. Initialize price feeds");
        console.log("4. Set up frontend integrations");
        console.log("5. Start marketing and user onboarding");
    }
}