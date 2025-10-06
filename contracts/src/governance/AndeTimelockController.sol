// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {TimelockControllerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AndeTimelockController
 * @author Ande Labs
 * @notice This contract provides a timelock mechanism for the AndeChain governance.
 * It enforces a delay between the moment a proposal is approved and when it can be executed,
 * giving users time to react to governance decisions.
 */
contract AndeTimelockController is Initializable, TimelockControllerUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the timelock controller.
     * @param minDelay The minimum delay in seconds for an operation to be executed.
     * @param proposers An array of addresses that are allowed to make proposals. (Typically the Governor contract).
     * @param executors An array of addresses that are allowed to execute proposals. (Can be anyone, or restricted).
     * @param admin The admin of this timelock. Can grant and revoke roles. (A multisig or another governance contract).
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        initializer
    {
        __TimelockController_init(minDelay, proposers, executors, admin);
    }
}
