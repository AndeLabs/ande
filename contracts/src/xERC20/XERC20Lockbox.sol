// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IXERC20Lockbox} from "../interfaces/IXERC20Lockbox.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title XERC20Lockbox
 * @author Ande Labs (adapted from ERC-7281 standard)
 * @notice Lockbox contract for wrapping ERC20 tokens into xERC20 tokens at 1:1 ratio
 * @dev Provides a secure bridge between existing ERC20 tokens and their xERC20 representation
 *
 * Key Features:
 * - 1:1 conversion between ERC20 and xERC20
 * - Reentrancy protection
 * - Support for deposit/withdraw to different addresses
 * - Immutable token addresses for security
 *
 * Use Case:
 * - For native chain: Users can lock their ERC20 tokens and receive xERC20 tokens
 *   that can be bridged to other chains
 * - When returning to native chain: Users can burn xERC20 and unlock their original ERC20
 */
contract XERC20Lockbox is IXERC20Lockbox, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== STATE VARIABLES ====================

    /// @notice The underlying ERC20 token that is locked
    IERC20 public immutable ERC20_TOKEN;

    /// @notice The xERC20 token that is minted/burned
    IXERC20 public immutable XERC20_TOKEN;

    // ==================== CONSTRUCTOR ====================

    /**
     * @notice Constructs the lockbox
     * @param _xerc20 Address of the xERC20 token
     * @param _erc20 Address of the underlying ERC20 token
     */
    constructor(address _xerc20, address _erc20) {
        if (_xerc20 == address(0) || _erc20 == address(0)) {
            revert IXERC20Lockbox_Invalid_Amount();
        }

        XERC20_TOKEN = IXERC20(_xerc20);
        ERC20_TOKEN = IERC20(_erc20);
    }

    // ==================== PUBLIC FUNCTIONS ====================

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function deposit(uint256 _amount) external {
        depositTo(msg.sender, _amount);
    }

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function depositTo(address _to, uint256 _amount) public nonReentrant {
        if (_amount == 0) revert IXERC20Lockbox_Invalid_Amount();

        // Transfer ERC20 tokens from sender to this lockbox
        ERC20_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);

        // Mint equivalent xERC20 tokens to recipient
        XERC20_TOKEN.mint(_to, _amount);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function withdraw(uint256 _amount) external {
        withdrawTo(msg.sender, _amount);
    }

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function withdrawTo(address _to, uint256 _amount) public nonReentrant {
        if (_amount == 0) revert IXERC20Lockbox_Invalid_Amount();

        // Burn xERC20 tokens from sender
        XERC20_TOKEN.burn(msg.sender, _amount);

        // Transfer equivalent ERC20 tokens from lockbox to recipient
        ERC20_TOKEN.safeTransfer(_to, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function ERC20() external view returns (address) {
        return address(ERC20_TOKEN);
    }

    /**
     * @inheritdoc IXERC20Lockbox
     */
    function XERC20() external view returns (address) {
        return address(XERC20_TOKEN);
    }
}
