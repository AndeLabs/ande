// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {XERC20} from "./XERC20.sol";

/**
 * @title xANDEToken
 * @author Ande Labs
 * @notice Cross-chain wrapper for ANDE token using xERC20 standard
 * @dev This is the bridgeable version of ANDE for use on non-native chains
 *
 * Architecture:
 * - On AndeChain (home chain): Users lock ANDE in lockbox → receive xANDE
 * - On other chains (destination): Bridges mint xANDE with rate limits
 * - When returning: Bridges burn xANDE → unlock ANDE from lockbox
 *
 * Key Properties:
 * - Inherits all XERC20 functionality (bridge limits, permit, upgradeable)
 * - Separate from native ANDE to preserve governance and gas token functionality
 * - 1:1 conversion via XERC20Lockbox on AndeChain
 * - Controlled minting/burning on destination chains via authorized bridges
 */
contract xANDEToken is XERC20 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the xANDE token
     * @dev Called once after proxy deployment
     * @param admin Address that will have admin and bridge manager roles
     */
    function initialize(address admin) public initializer {
        super.initialize("Cross-Chain ANDE", "xANDE", admin);
    }
}
