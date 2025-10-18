// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/account/EntryPoint.sol";
import "../src/account/ANDEPaymaster.sol";
import "../src/account/interfaces/IPriceOracle.sol";
import "../src/account/factories/SimpleAccountFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../test/account/mocks/MockPriceOracle.sol";

/**
 * @title DeployAccountAbstraction
 * @notice Deployment script for Account Abstraction infrastructure on AndeChain
 * @dev Deploys EntryPoint, ANDEPaymaster, and SimpleAccountFactory for ERC-4337 support
 */
contract DeployAccountAbstraction is Script {
    // Deployment addresses will be saved here
    EntryPoint public entryPoint;
    ANDEPaymaster public andePaymaster;
    SimpleAccountFactory public accountFactory;
    MockPriceOracle public priceOracle;
    address public andeTokenAddress;

    address public deployer;

    function setUp() public {}

    function run() public {
        // Get deployer address
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("========================================");
        console.log("Account Abstraction Deployment");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy EntryPoint (canonical ERC-4337 v0.6)
        console.log("1. Deploying EntryPoint...");
        entryPoint = new EntryPoint();
        console.log("   EntryPoint deployed at:", address(entryPoint));
        console.log("");

        // 2. Get ANDE Token address (must be pre-deployed)
        andeTokenAddress = vm.envAddress("ANDE_TOKEN_ADDRESS");
        console.log("2. Using ANDE Token at:", andeTokenAddress);
        console.log("");

        // 3. Deploy Price Oracle (MockPriceOracle for now)
        console.log("3. Deploying Price Oracle...");
        priceOracle = new MockPriceOracle();
        console.log("   Price Oracle deployed at:", address(priceOracle));

        // Set initial ANDE price: 1 ANDE = 1 ETH (1e18)
        priceOracle.setPrice(andeTokenAddress, 1e18);
        console.log("   Initial ANDE price set: 1 ANDE = 1 ETH");
        console.log("");

        // 4. Deploy SimpleAccountFactory
        console.log("4. Deploying SimpleAccountFactory...");
        accountFactory = new SimpleAccountFactory(entryPoint);
        console.log("   SimpleAccountFactory deployed at:", address(accountFactory));
        console.log("");

        // 5. Deploy ANDEPaymaster
        console.log("5. Deploying ANDEPaymaster...");
        andePaymaster = new ANDEPaymaster(
            andeTokenAddress,
            IPriceOracle(address(priceOracle)),
            address(accountFactory),
            entryPoint,
            deployer // Owner
        );
        console.log("   ANDEPaymaster deployed at:", address(andePaymaster));
        console.log("   Paymaster owner:", deployer);
        console.log("");

        // 6. Fund ANDEPaymaster with ETH for gas sponsorship
        console.log("6. Funding ANDEPaymaster...");
        uint256 paymasterDeposit = 10 ether; // Default 10 ETH
        andePaymaster.deposit{value: paymasterDeposit}();
        console.log("   Deposited", paymasterDeposit / 1 ether, "ETH to EntryPoint");
        console.log("   Paymaster EntryPoint balance:", andePaymaster.getDeposit() / 1 ether, "ETH");
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("========================================");
        console.log("Deployment Complete!");
        console.log("========================================");
        console.log("");
        console.log("Contract Addresses:");
        console.log("-------------------");
        console.log("EntryPoint:           ", address(entryPoint));
        console.log("ANDE Token:           ", andeTokenAddress);
        console.log("Price Oracle:         ", address(priceOracle));
        console.log("SimpleAccountFactory: ", address(accountFactory));
        console.log("ANDEPaymaster:        ", address(andePaymaster));
        console.log("");
        console.log("Configuration:");
        console.log("--------------");
        console.log("Max Gas Limit:        ", andePaymaster.getMaxGasLimit());
        console.log("ANDE/ETH Price:       ", andePaymaster.getCurrentExchangeRate());
        console.log("Whitelist Enabled:    ", false);
        console.log("");
        console.log("Next Steps:");
        console.log("-----------");
        console.log("1. Create a smart wallet:");
        console.log("   address wallet = accountFactory.createAccount(ownerAddress, salt);");
        console.log("");
        console.log("2. Fund the wallet with ANDE tokens for gas payments");
        console.log("");
        console.log("3. Approve ANDEPaymaster to spend ANDE tokens from the wallet:");
        console.log("   andeToken.approve(address(andePaymaster), amount);");
        console.log("");
        console.log("4. Submit UserOperations through EntryPoint with paymaster field set");
        console.log("");
        console.log("========================================");

        // Save addresses to file for later use
        _saveDeployment();
    }

    function _saveDeployment() internal {
        string memory deploymentInfo = string.concat(
            "# Account Abstraction Deployment\n",
            "# Deployed on chain: ", vm.toString(block.chainid), "\n",
            "# Deployed by: ", vm.toString(deployer), "\n",
            "# Timestamp: ", vm.toString(block.timestamp), "\n\n",
            "ENTRY_POINT=", vm.toString(address(entryPoint)), "\n",
            "ANDE_TOKEN=", vm.toString(andeTokenAddress), "\n",
            "PRICE_ORACLE=", vm.toString(address(priceOracle)), "\n",
            "ACCOUNT_FACTORY=", vm.toString(address(accountFactory)), "\n",
            "ANDE_PAYMASTER=", vm.toString(address(andePaymaster)), "\n"
        );

        vm.writeFile("deployments/account-abstraction.env", deploymentInfo);
        console.log("Deployment addresses saved to deployments/account-abstraction.env");
    }
}
