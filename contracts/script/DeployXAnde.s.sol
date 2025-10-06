// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {xANDEToken} from "../src/xERC20/xANDEToken.sol";
import {XERC20Lockbox} from "../src/xERC20/XERC20Lockbox.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployXAnde
 * @author Ande Labs
 * @notice This script deploys the xANDEToken and its XERC20Lockbox.
 * It requires the following environment variables to be set:
 * - ANDE_TOKEN_ADDRESS: The address of the underlying ANDEToken contract.
 * - XANDE_ADMIN_ADDRESS: The address that will be the admin of the xANDEToken.
 * - PRIVATE_KEY: The private key of the deployer.
 */
contract DeployXAnde is Script {
    address private andeTokenAddress;
    address private xandeAdminAddress;

    function setUp() public {
        andeTokenAddress = vm.envAddress("ANDE_TOKEN_ADDRESS");
        xandeAdminAddress = vm.envAddress("XANDE_ADMIN_ADDRESS");

        require(andeTokenAddress != address(0), "ANDE_TOKEN_ADDRESS env var not set");
        require(xandeAdminAddress != address(0), "XANDE_ADMIN_ADDRESS env var not set");
    }

    function run() public returns (xANDEToken, XERC20Lockbox) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the xANDEToken implementation
        xANDEToken xAndeImplementation = new xANDEToken();
        console.log("xANDEToken implementation deployed to:", address(xAndeImplementation));

        // 2. Deploy the ERC1967Proxy for xANDEToken
        bytes memory initData = abi.encodeWithSelector(xANDEToken.initialize.selector, xandeAdminAddress);
        ERC1967Proxy xAndeProxy = new ERC1967Proxy(address(xAndeImplementation), initData);
        xANDEToken xAnde = xANDEToken(address(xAndeProxy));
        console.log("xANDEToken proxy deployed to:", address(xAnde));

        // 3. Deploy the XERC20Lockbox
        XERC20Lockbox lockbox = new XERC20Lockbox(address(xAnde), andeTokenAddress);
        console.log("XERC20Lockbox deployed to:", address(lockbox));

        // 4. Set the lockbox address in the xANDEToken contract
        // The deployer is the admin at this point, so it can call setLockbox
        xAnde.setLockbox(address(lockbox));
        console.log("Lockbox address set in xANDEToken");

        vm.stopBroadcast();

        return (xAnde, lockbox);
    }
}
