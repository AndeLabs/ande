// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AbobTokenV2} from "../src/AbobTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployAbob
 * @author Ande Labs
 * @notice This script deploys the AbobTokenV2 contract.
 * It requires the following environment variables to be set:
 * - ABOB_ADMIN_ADDRESS: The address that will be the admin of the AbobTokenV2.
 * - AUSD_TOKEN_ADDRESS: The address of the AUSD token contract.
 * - ANDE_TOKEN_ADDRESS: The address of the ANDE token contract.
 * - ANDE_PRICE_FEED_ADDRESS: The address of the ANDE/USD price feed oracle.
 * - ABOB_PRICE_FEED_ADDRESS: The address of the ABOB/USD price feed oracle.
 * - INITIAL_RATIO: The initial collateral ratio in basis points.
 * - PRIVATE_KEY: The private key of the deployer.
 */
contract DeployAbob is Script {
    address private abobAdminAddress;
    address private ausdTokenAddress;
    address private andeTokenAddress;
    address private andePriceFeedAddress;
    address private abobPriceFeedAddress;
    uint256 private initialRatio;

    function setUp() public {
        abobAdminAddress = vm.envAddress("ABOB_ADMIN_ADDRESS");
        ausdTokenAddress = vm.envAddress("AUSD_TOKEN_ADDRESS");
        andeTokenAddress = vm.envAddress("ANDE_TOKEN_ADDRESS");
        andePriceFeedAddress = vm.envAddress("ANDE_PRICE_FEED_ADDRESS");
        abobPriceFeedAddress = vm.envAddress("ABOB_PRICE_FEED_ADDRESS");
        initialRatio = vm.envUint("INITIAL_RATIO");

        require(abobAdminAddress != address(0), "ABOB_ADMIN_ADDRESS env var not set");
        require(ausdTokenAddress != address(0), "AUSD_TOKEN_ADDRESS env var not set");
        require(andeTokenAddress != address(0), "ANDE_TOKEN_ADDRESS env var not set");
        require(andePriceFeedAddress != address(0), "ANDE_PRICE_FEED_ADDRESS env var not set");
        require(abobPriceFeedAddress != address(0), "ABOB_PRICE_FEED_ADDRESS env var not set");
    }

    function run() public returns (AbobTokenV2) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the AbobTokenV2 implementation
        AbobTokenV2 abobImplementation = new AbobTokenV2();
        console.log("AbobTokenV2 implementation deployed to:", address(abobImplementation));

        // 2. Deploy the ERC1967Proxy for AbobTokenV2
        bytes memory initData = abi.encodeWithSelector(
            AbobTokenV2.initialize.selector,
            abobAdminAddress,
            ausdTokenAddress,
            andeTokenAddress,
            andePriceFeedAddress,
            abobPriceFeedAddress,
            initialRatio
        );
        ERC1967Proxy abobProxy = new ERC1967Proxy(address(abobImplementation), initData);
        AbobTokenV2 abob = AbobTokenV2(address(abobProxy));
        console.log("AbobTokenV2 proxy deployed to:", address(abob));

        vm.stopBroadcast();

        return abob;
    }
}
