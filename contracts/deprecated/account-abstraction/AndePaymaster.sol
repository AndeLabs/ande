// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    VerifyingPaymaster
} from "@openzeppelin/contracts/samples/erc4337/VerifyingPaymaster.sol";

/**
 * @title AndePaymaster
 * @author Gemini
 * @notice This contract sponsors gas fees for user operations if they provide a valid
 * signature from a trusted off-chain authority (the paymaster signer).
 * This allows for gasless transactions for the end-user.
 */
contract AndePaymaster is VerifyingPaymaster {
    constructor(
        IEntryPoint _entryPoint,
        address _signer
    ) VerifyingPaymaster(_entryPoint, _signer) {}

    // The core logic for validating paymaster signatures is handled by
    // OpenZeppelin's VerifyingPaymaster.

    // The off-chain service will need to generate a signature over the UserOperation hash.
    // The `validatePaymasterUserOp` function will then use this signature to verify
    // that the operation is approved for gas sponsorship.
}
