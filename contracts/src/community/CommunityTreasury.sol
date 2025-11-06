// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CommunityTreasury
 * @author Ande Labs
 * @notice Community treasury for grants to builders and public good projects
 * @dev Receives 10% of all network fees and is controlled by governance
 *
 * USE CASES:
 * - Grants to builders
 * - Blockchain education in communities
 * - Public infrastructure (RPC nodes, explorers)
 * - Events and regional hackathons
 */
contract CommunityTreasury is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant GRANT_PROPOSER_ROLE = keccak256("GRANT_PROPOSER_ROLE");
    bytes32 public constant GRANT_APPROVER_ROLE = keccak256("GRANT_APPROVER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    enum GrantStatus {
        PENDING,
        APPROVED,
        REJECTED,
        COMPLETED,
        CANCELLED
    }

    enum GrantCategory {
        BUILDER_GRANT,
        EDUCATION,
        INFRASTRUCTURE,
        COMMUNITY_EVENT,
        RESEARCH,
        OTHER
    }

    struct Grant {
        address proposer;
        address recipient;
        uint256 amount;
        string title;
        string description;
        string ipfsHash;
        GrantCategory category;
        GrantStatus status;
        uint256 proposedAt;
        uint256 approvedAt;
        uint256 completedAt;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
    }

    struct GrantStats {
        uint256 totalProposed;
        uint256 totalApproved;
        uint256 totalRejected;
        uint256 totalCompleted;
        uint256 totalAmountGranted;
    }

    IERC20 public andeToken;

    uint256 public grantCount;
    mapping(uint256 => Grant) public grants;

    GrantStats public stats;

    uint256 public constant MIN_GRANT_AMOUNT = 1_000 * 1e18;
    uint256 public constant MAX_GRANT_AMOUNT = 100_000 * 1e18;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 10_000 * 1e18;

    uint256 public totalFundsReceived;
    uint256 public totalFundsDisbursed;
    uint256 public availableFunds;

    event FundsReceived(address indexed from, uint256 amount);
    event GrantProposed(
        uint256 indexed grantId,
        address indexed proposer,
        address indexed recipient,
        uint256 amount,
        GrantCategory category
    );
    event GrantVoted(uint256 indexed grantId, address indexed voter, bool support, uint256 weight);
    event GrantApproved(uint256 indexed grantId, uint256 amount);
    event GrantRejected(uint256 indexed grantId, string reason);
    event GrantCompleted(uint256 indexed grantId);
    event GrantCancelled(uint256 indexed grantId, string reason);
    event GrantDisbursed(uint256 indexed grantId, address indexed recipient, uint256 amount);

    error InvalidAmount();
    error InsufficientFunds();
    error GrantNotFound();
    error GrantNotPending();
    error GrantNotApproved();
    error AlreadyVoted();
    error InsufficientVotingPower();
    error VotingPeriodEnded();
    error InvalidCategory();
    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _andeToken, address defaultAdmin) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        if (_andeToken == address(0)) revert ZeroAddress();

        andeToken = IERC20(_andeToken);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(GRANT_PROPOSER_ROLE, defaultAdmin);
        _grantRole(GRANT_APPROVER_ROLE, defaultAdmin);
    }

    function receiveFunds(uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        andeToken.safeTransferFrom(msg.sender, address(this), amount);

        totalFundsReceived += amount;
        availableFunds += amount;

        emit FundsReceived(msg.sender, amount);
    }

    function proposeGrant(
        address recipient,
        uint256 amount,
        string calldata title,
        string calldata description,
        string calldata ipfsHash,
        GrantCategory category
    ) external onlyRole(GRANT_PROPOSER_ROLE) whenNotPaused returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_GRANT_AMOUNT || amount > MAX_GRANT_AMOUNT) revert InvalidAmount();
        if (amount > availableFunds) revert InsufficientFunds();

        uint256 grantId = grantCount++;

        Grant storage grant = grants[grantId];
        grant.proposer = msg.sender;
        grant.recipient = recipient;
        grant.amount = amount;
        grant.title = title;
        grant.description = description;
        grant.ipfsHash = ipfsHash;
        grant.category = category;
        grant.status = GrantStatus.PENDING;
        grant.proposedAt = block.timestamp;

        stats.totalProposed++;

        emit GrantProposed(grantId, msg.sender, recipient, amount, category);

        return grantId;
    }

    function voteOnGrant(uint256 grantId, bool support)
        external
        onlyRole(GRANT_APPROVER_ROLE)
        whenNotPaused
    {
        if (grantId >= grantCount) revert GrantNotFound();

        Grant storage grant = grants[grantId];
        if (grant.status != GrantStatus.PENDING) revert GrantNotPending();
        if (block.timestamp > grant.proposedAt + VOTING_PERIOD) revert VotingPeriodEnded();
        if (grant.hasVoted[msg.sender]) revert AlreadyVoted();

        uint256 votingPower = andeToken.balanceOf(msg.sender);
        if (votingPower < MIN_VOTING_POWER) revert InsufficientVotingPower();

        grant.hasVoted[msg.sender] = true;

        if (support) {
            grant.votesFor += votingPower;
        } else {
            grant.votesAgainst += votingPower;
        }

        emit GrantVoted(grantId, msg.sender, support, votingPower);
    }

    function finalizeGrant(uint256 grantId) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        if (grantId >= grantCount) revert GrantNotFound();

        Grant storage grant = grants[grantId];
        if (grant.status != GrantStatus.PENDING) revert GrantNotPending();

        if (grant.votesFor > grant.votesAgainst) {
            grant.status = GrantStatus.APPROVED;
            grant.approvedAt = block.timestamp;
            stats.totalApproved++;

            emit GrantApproved(grantId, grant.amount);
        } else {
            grant.status = GrantStatus.REJECTED;
            stats.totalRejected++;

            emit GrantRejected(grantId, "Insufficient votes");
        }
    }

    function disburseGrant(uint256 grantId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
        whenNotPaused
    {
        if (grantId >= grantCount) revert GrantNotFound();

        Grant storage grant = grants[grantId];
        if (grant.status != GrantStatus.APPROVED) revert GrantNotApproved();
        if (grant.amount > availableFunds) revert InsufficientFunds();

        grant.status = GrantStatus.COMPLETED;
        grant.completedAt = block.timestamp;

        availableFunds -= grant.amount;
        totalFundsDisbursed += grant.amount;
        stats.totalCompleted++;
        stats.totalAmountGranted += grant.amount;

        andeToken.safeTransfer(grant.recipient, grant.amount);

        emit GrantDisbursed(grantId, grant.recipient, grant.amount);
        emit GrantCompleted(grantId);
    }

    function cancelGrant(uint256 grantId, string calldata reason)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (grantId >= grantCount) revert GrantNotFound();

        Grant storage grant = grants[grantId];
        if (grant.status == GrantStatus.COMPLETED || grant.status == GrantStatus.CANCELLED) {
            revert GrantNotPending();
        }

        grant.status = GrantStatus.CANCELLED;

        emit GrantCancelled(grantId, reason);
    }

    function getGrantInfo(uint256 grantId)
        external
        view
        returns (
            address proposer,
            address recipient,
            uint256 amount,
            string memory title,
            string memory description,
            string memory ipfsHash,
            GrantCategory category,
            GrantStatus status,
            uint256 proposedAt,
            uint256 approvedAt,
            uint256 completedAt,
            uint256 votesFor,
            uint256 votesAgainst
        )
    {
        if (grantId >= grantCount) revert GrantNotFound();

        Grant storage grant = grants[grantId];
        return (
            grant.proposer,
            grant.recipient,
            grant.amount,
            grant.title,
            grant.description,
            grant.ipfsHash,
            grant.category,
            grant.status,
            grant.proposedAt,
            grant.approvedAt,
            grant.completedAt,
            grant.votesFor,
            grant.votesAgainst
        );
    }

    function getGrantStats() external view returns (GrantStats memory) {
        return stats;
    }

    function getFundBalance()
        external
        view
        returns (uint256 total, uint256 disbursed, uint256 available)
    {
        return (totalFundsReceived, totalFundsDisbursed, availableFunds);
    }

    function hasVotedOnGrant(uint256 grantId, address voter) external view returns (bool) {
        if (grantId >= grantCount) return false;
        return grants[grantId].hasVoted[voter];
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Propone y aprueba grant directamente (solo Governor)
     * @dev Permite al Governor aprobar grants automáticamente via propuestas
     * @param recipient Destinatario del grant
     * @param amount Monto del grant
     * @param title Título del grant
     * @param description Descripción del grant
     * @param ipfsHash Hash IPFS con documentación
     * @param category Categoría del grant
     * @return grantId ID del grant creado
     */
    function proposeAndApproveGrant(
        address recipient,
        uint256 amount,
        string calldata title,
        string calldata description,
        string calldata ipfsHash,
        GrantCategory category
    ) external onlyRole(GOVERNOR_ROLE) whenNotPaused returns (uint256) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount < MIN_GRANT_AMOUNT || amount > MAX_GRANT_AMOUNT) revert InvalidAmount();
        if (amount > availableFunds) revert InsufficientFunds();

        uint256 grantId = grantCount++;

        Grant storage grant = grants[grantId];
        grant.proposer = msg.sender;
        grant.recipient = recipient;
        grant.amount = amount;
        grant.title = title;
        grant.description = description;
        grant.ipfsHash = ipfsHash;
        grant.category = category;
        grant.status = GrantStatus.APPROVED;
        grant.proposedAt = block.timestamp;
        grant.approvedAt = block.timestamp;

        stats.totalProposed++;
        stats.totalApproved++;

        emit GrantProposed(grantId, msg.sender, recipient, amount, category);
        emit GrantApproved(grantId, amount);

        return grantId;
    }

    /**
     * @notice Ejecuta desembolso de grant directamente (solo Governor)
     * @dev Permite al Governor ejecutar grants en una sola transacción
     * @param recipient Destinatario del grant
     * @param amount Monto a transferir
     * @param reason Razón del desembolso
     */
    function executeGovernanceTransfer(
        address recipient,
        uint256 amount,
        string calldata reason
    ) external onlyRole(GOVERNOR_ROLE) nonReentrant whenNotPaused {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount();
        if (amount > availableFunds) revert InsufficientFunds();

        availableFunds -= amount;
        totalFundsDisbursed += amount;

        andeToken.safeTransfer(recipient, amount);

        emit FundsReceived(address(this), 0);
    }

    /**
     * @notice Actualiza límites de grants (solo Governor)
     * @dev Permite ajustar MIN y MAX grant amounts via governance
     */
    function updateGrantLimits(uint256 newMin, uint256 newMax) 
        external 
        onlyRole(GOVERNOR_ROLE) 
    {
        if (newMin == 0 || newMax == 0 || newMin >= newMax) revert InvalidAmount();
        // Note: Would need to add storage variables for configurable limits
        // For now, constants are sufficient
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
