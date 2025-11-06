// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WAndeVault (Wrapped ANDE Vault)
 * @author Gemini
 * @notice This contract is an ERC-4626 compliant vault for wrapping the native ANDEToken.
 * It provides a standardized way to deposit ANDEToken and receive vault shares (vaANDE),
 * which can then be used in other DeFi protocols, such as staking.
 *
 * This implementation uses a 1:1 share-to-asset ratio, meaning 1 vaANDE share always
 * represents 1 underlying ANDEToken.
 */
contract WAndeVault is ERC4626 {
    /**
     * @notice Constructs the WAndeVault.
     * @param _asset The address of the underlying ANDEToken (ERC-20).
     */
    constructor(IERC20 _asset) ERC20("Vault ANDE", "vaANDE") ERC4626(_asset) {}

    // By default, ERC4626 is a 1:1 vault if no yield-generating mechanism is added.
    // The totalAssets() function will reflect the balance of the underlying asset held by the vault.
    // The following functions are all inherited from ERC4626 and work out-of-the-box:
    // - deposit(assets, receiver)
    // - mint(shares, receiver)
    // - withdraw(assets, receiver, owner)
    // - redeem(shares, receiver, owner)
    // - convertToShares(assets)
    // - convertToAssets(shares)
}
