// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {AndeSequencerCoordinator} from "../src/sequencer/AndeSequencerCoordinator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySequencerCoordinator is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address andeToken = vm.envAddress("ANDE_TOKEN");
        address emergencySequencer = vm.envOr("EMERGENCY_SEQUENCER", msg.sender);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation
        AndeSequencerCoordinator implementation = new AndeSequencerCoordinator();
        console.log("Implementation deployed at:", address(implementation));

        // 2. Encode initialize call
        bytes memory initData = abi.encodeWithSelector(
            AndeSequencerCoordinator.initialize.selector,
            msg.sender, // defaultAdmin
            andeToken,
            emergencySequencer
        );

        // 3. Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed at:", address(proxy));

        AndeSequencerCoordinator coordinator = AndeSequencerCoordinator(address(proxy));

        console.log("=================================");
        console.log("AndeSequencerCoordinator Deployed");
        console.log("=================================");
        console.log("Proxy:", address(proxy));
        console.log("Implementation:", address(implementation));
        console.log("ANDE Token:", andeToken);
        console.log("Emergency Sequencer:", emergencySequencer);
        console.log("Current Leader:", coordinator.currentLeader());
        console.log("Active Sequencers:", coordinator.getActiveSequencers().length);

        vm.stopBroadcast();
    }
}
