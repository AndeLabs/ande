// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StakingVault
 * @author Gemini & Ande Labs
 * @notice An upgradeable, pausable, ERC-7540-style Asynchronous Vault for staking `vaANDE` to get `stANDE`.
 * @dev The `stANDE` shares issued by this vault are vote-enabled (ERC20Votes).
 * Withdrawals are subject to an unbonding period.
 */
contract StakingVault is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // --- Roles ---
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // --- State Variables ---
    IERC20 public asset;
    uint256 public unbondingPeriod;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 private _nextRequestId;

    // --- Structs ---
    struct WithdrawalRequest {
        address owner;
        address receiver;
        uint256 assets;
        uint256 claimableAt;
    }

    // --- Events ---
    event WithdrawalRequested(
        uint256 indexed requestId, address indexed owner, address indexed receiver, uint256 shares, uint256 assets
    );
    event WithdrawalClaimed(uint256 indexed requestId, address indexed owner, address indexed receiver, uint256 assets);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address defaultAdmin, IERC20 _asset, uint256 _unbondingPeriod) public initializer {
        __ERC20_init("Staked ANDE", "stANDE");
        __ERC20Permit_init("Staked ANDE");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);

        asset = _asset;
        unbondingPeriod = _unbondingPeriod;
    }

    // --- Pausable Control ---
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // --- Core Staking Logic (Simplified Deposit) ---
    function deposit(uint256 assetsToDeposit, address receiver) external whenNotPaused returns (uint256 sharesMinted) {
        sharesMinted = assetsToDeposit;
        require(sharesMinted > 0, "Deposit amount cannot be zero");

        _mint(receiver, sharesMinted);
        asset.safeTransferFrom(msg.sender, address(this), assetsToDeposit);
    }

    // --- Asynchronous Withdrawal Logic (ERC-7540 Pattern) ---
    function requestWithdrawal(uint256 sharesToBurn, address receiver)
        external
        whenNotPaused
        returns (uint256 requestId)
    {
        require(sharesToBurn > 0, "Shares to burn cannot be zero");
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

    function claimWithdrawal(uint256 requestId) external whenNotPaused {
        WithdrawalRequest storage request = withdrawalRequests[requestId];

        require(request.owner != address(0), "Request does not exist");
        require(msg.sender == request.owner, "Only the request owner can claim");
        require(block.timestamp >= request.claimableAt, "Unbonding period has not passed");

        uint256 assetsToClaim = request.assets;
        address receiver = request.receiver;

        delete withdrawalRequests[requestId];

        asset.safeTransfer(receiver, assetsToClaim);

        emit WithdrawalClaimed(requestId, msg.sender, receiver, assetsToClaim);
    }

    // --- ERC20Votes/UUPS/Pausable Required Overrides ---

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
        whenNotPaused
    {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
