// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StakingVault
 * @author Gemini
 * @notice This is a skeletal implementation of an ERC-7540 Asynchronous Vault for staking.
 * It accepts a base asset (e.g., vaANDE) and issues staking shares (stANDE).
 * Withdrawals are subject to an unbonding period.
 *
 * WARNING: This is a conceptual implementation based on the ERC-7540 EIP.
 * It has not been audited and lacks many production-ready features like role-based access,
 * detailed event emissions, and robust checks. Use as a structural foundation.
 */
contract StakingVault is ERC20 {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    // The underlying asset this vault holds and stakes (e.g., vaANDE)
    IERC20 public immutable asset;

    // The period users must wait after requesting a withdrawal before they can claim assets.
    uint256 public immutable unbondingPeriod;

    // Mapping from a request ID to a withdrawal request details.
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;

    // Counter for generating unique request IDs.
    uint256 private _nextRequestId;

    // --- Structs ---

    struct WithdrawalRequest {
        address owner;      // The user who requested the withdrawal.
        address receiver;   // The user who will receive the assets.
        uint256 assets;     // The amount of underlying assets to be claimed.
        uint256 claimableAt; // The timestamp when the assets become claimable.
    }

    // --- Events ---

    event WithdrawalRequested(uint256 indexed requestId, address indexed owner, address indexed receiver, uint256 shares, uint256 assets);
    event WithdrawalClaimed(uint256 indexed requestId, address indexed owner, address indexed receiver, uint256 assets);

    // --- Constructor ---

    constructor(IERC20 _asset, uint256 _unbondingPeriod) ERC20("Staked ANDE", "stANDE") {
        asset = _asset;
        unbondingPeriod = _unbondingPeriod;
    }

    // --- Core Staking Logic (Simplified Deposit) ---

    /**
     * @notice Deposits assets into the vault and immediately mints staking shares.
     * A full ERC-7540 implementation would make this asynchronous as well.
     * For this staking use-case, we simplify to an immediate mint.
     */
    function deposit(uint256 assetsToDeposit, address receiver) external returns (uint256 sharesMinted) {
        // For a 1:1 staking vault, shares minted = assets deposited.
        sharesMinted = assetsToDeposit;

        if (sharesMinted == 0) {
            revert("Deposit amount cannot be zero");
        }

        _mint(receiver, sharesMinted);
        asset.safeTransferFrom(msg.sender, address(this), assetsToDeposit);
    }

    // --- Asynchronous Withdrawal Logic (ERC-7540 Pattern) ---

    /**
     * @notice Request to withdraw assets from the vault by burning shares.
     * The assets will be claimable after the `unbondingPeriod`.
     */
    function requestWithdrawal(uint256 sharesToBurn, address receiver) external returns (uint256 requestId) {
        if (sharesToBurn == 0) {
            revert("Shares to burn cannot be zero");
        }

        // For a 1:1 staking vault, assets to withdraw = shares burned.
        uint256 assetsToWithdraw = sharesToBurn;

        _burn(msg.sender, sharesToBurn);

        requestId = ++_nextRequestId;

        withdrawalRequests[requestId] = WithdrawalRequest({
            owner: msg.sender,
            receiver: receiver,
            assets: assetsToWithdraw,
            claimableAt: block.timestamp + unbondingPeriod
        });

        emit WithdrawalRequested(requestId, msg.sender, receiver, sharesToBurn, assetsToWithdraw);
    }

    /**
     * @notice Claim assets from a previously requested withdrawal.
     */
    function claimWithdrawal(uint256 requestId) external {
        WithdrawalRequest storage request = withdrawalRequests[requestId];

        if (request.owner == address(0)) {
            revert("Request does not exist");
        }
        if (msg.sender != request.owner) {
            revert("Only the request owner can claim");
        }
        if (block.timestamp < request.claimableAt) {
            revert("Unbonding period has not passed");
        }

        uint256 assetsToClaim = request.assets;

        address receiver = request.receiver;

        // Mark as claimed by deleting the request
        delete withdrawalRequests[requestId];

        asset.safeTransfer(receiver, assetsToClaim);

        emit WithdrawalClaimed(requestId, msg.sender, receiver, assetsToClaim);
    }
}
