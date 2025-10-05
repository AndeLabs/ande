// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ERC4337Account
} from "@openzeppelin/contracts/samples/erc4337/ERC4337Account.sol";

/**
 * @title AndeAccount
 * @author Gemini
 * @notice This is a user's smart contract wallet, compliant with ERC-4337.
 * It is owned by an EOA and can execute transactions on the user's behalf.
 * This contract can hold assets (ANDE, vaANDE, stANDE) and interact with the vaults.
 */
contract AndeAccount is ERC4337Account {
    constructor(
        IEntryPoint _entryPoint,
        address _owner
    ) ERC4337Account(_entryPoint, _owner) {}

    // The core logic for validateUserOp, execute, etc., is inherited from
    // OpenZeppelin's ERC4337Account. This provides a secure and standard base.
    // Custom logic, such as multi-sig or recovery mechanisms, could be added here later.
}
