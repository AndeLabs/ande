// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AusdTokenV2} from "../src/AusdTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployAusd
 * @author Ande Labs
 * @notice This script deploys the AusdTokenV2 contract.
 * It requires the following environment variables to be set:
 * - AUSD_ADMIN_ADDRESS: The address that will be the admin of the AusdTokenV2.
 * - PRIVATE_KEY: The private key of the deployer.
 */
contract DeployAusd is Script {
    address private ausdAdminAddress;

    function setUp() public {
        ausdAdminAddress = vm.envAddress("AUSD_ADMIN_ADDRESS");
        require(ausdAdminAddress != address(0), "AUSD_ADMIN_ADDRESS env var not set");
    }

    function run() public returns (AusdTokenV2) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the AusdTokenV2 implementation
        AusdTokenV2 ausdImplementation = new AusdTokenV2();
        console.log("AusdTokenV2 implementation deployed to:", address(ausdImplementation));

        // 2. Deploy the ERC1967Proxy for AusdTokenV2
        bytes memory initData = abi.encodeWithSelector(
            AusdTokenV2.initialize.selector,
            ausdAdminAddress
        );
        ERC1967Proxy ausdProxy = new ERC1967Proxy(address(ausdImplementation), initData);
        AusdTokenV2 ausd = AusdTokenV2(address(ausdProxy));
        console.log("AusdTokenV2 proxy deployed to:", address(ausd));

        vm.stopBroadcast();

        return ausd;
    }
}
