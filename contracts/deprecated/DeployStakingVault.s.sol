// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StakingVault} from "../src/staking/StakingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployStakingVault
 * @author Gemini
 * @notice This script deploys the StakingVault contract.
 * It requires the W_ANDE_VAULT_ADDRESS and PRIVATE_KEY environment variables.
 * UNBONDING_PERIOD is optional and defaults to 7 days.
 */
contract DeployStakingVault is Script {
    address private wAndeVaultAddress;
    uint256 private unbondingPeriod;

    function setUp() public {
        // Load contract address and config from environment variables
        wAndeVaultAddress = vm.envAddress("W_ANDE_VAULT_ADDRESS");
        // Default to 7 days if the environment variable is not set
        unbondingPeriod = vm.envOr("UNBONDING_PERIOD", uint256(7 days));

        require(wAndeVaultAddress != address(0), "W_ANDE_VAULT_ADDRESS env var not set");
    }

    function run() public returns (StakingVault) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the StakingVault with its asset (WAndeVault) and unbonding period
        StakingVault stakingVault = new StakingVault(IERC20(wAndeVaultAddress), unbondingPeriod);

        vm.stopBroadcast();

        console.log("StakingVault deployed to:", address(stakingVault));
        console.log("Underlying Asset (WAndeVault):", wAndeVaultAddress);
        console.log("Unbonding Period (seconds):", unbondingPeriod);

        return stakingVault;
    }
}
