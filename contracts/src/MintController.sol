// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VeANDE} from "./VeANDE.sol";

interface IMintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title MintController
 * @author Ande Labs
 * @notice Contrato de gobernanza para controlar la acuñación (minting) de nuevos tokens $ANDE.
 * @dev Implementa un sistema de propuestas con votación, quórum, supermayoría y timelock para garantizar
 * un proceso de emisión de tokens seguro, descentralizado y predecible.
 */
contract MintController is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IMintable;

    // ============================================
    // ROLES
    // ============================================
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // ============================================
    // STATE VARIABLES
    // ============================================
    IMintable public andeToken;
    VeANDE public veANDE;

    // Economic parameters
    uint256 public hardCap;
    uint256 public totalMinted;
    uint256 public annualMintLimit;
    uint256 public lastMintYear;
    uint256 public mintedThisYear;

    // Governance parameters
    uint256 public constant SUPERMAJORITY_THRESHOLD = 7500; // 75% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public quorumPercentage; // Minimum % of total voting power needed
    uint256 public votingPeriod; // Duration proposals remain open for voting
    uint256 public executionDelay; // Timelock delay before execution
    uint256 public proposalLifetime; // Time after which proposals expire

    // Proposal tracking
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed,
        Cancelled,
        Expired
    }

    struct MintProposal {
        uint256 amount;
        address recipient;
        uint256 snapshotBlock; // Block number for voting power snapshot
        uint256 creationTime;
        uint256 votingDeadline;
        uint256 executionETA; // Earliest time for execution (after timelock)
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotingPowerAtSnapshot;
        bool executed;
        bool cancelled;
        string description;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => MintProposal) public proposals;
    uint256 public proposalCount;

    // Batch minting limits (for security)
    uint256 public maxProposalAmount;
    uint256 public minProposalAmount;

    // ============================================
    // ERRORS
    // ============================================
    error InvalidTokenAddress();
    error InvalidVeANDEAddress();
    error InvalidHardCap();
    error InvalidParameters();
    error ExceedsHardCap();
    error ExceedsAnnualLimit();
    error ExceedsMaxProposalAmount();
    error BelowMinProposalAmount();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalIsCancelled();
    error ProposalHasExpired();
    error ProposalNotActive();
    error ProposalNotSucceeded();
    error ProposalTimelockNotMet();
    error SupermajorityNotReached();
    error QuorumNotReached();
    error AlreadyVoted();
    error NoVotingPower();
    error VotingPeriodEnded();
    error VotingPeriodNotEnded();
    error InvalidRecipient();
    error ZeroAmount();

    // ============================================
    // EVENTS
    // ============================================
    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 amount,
        address indexed recipient,
        uint256 snapshotBlock,
        uint256 votingDeadline,
        string description
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 voteWeight,
        uint256 votesFor,
        uint256 votesAgainst
    );
    
    event ProposalQueued(
        uint256 indexed proposalId,
        uint256 executionETA
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 amount,
        address indexed recipient
    );
    
    event ProposalCancelled(uint256 indexed proposalId);
    
    event ProposalExpired(uint256 indexed proposalId);
    
    event GovernanceParametersUpdated(
        uint256 quorumPercentage,
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 proposalLifetime
    );
    
    event MintLimitsUpdated(
        uint256 annualMintLimit,
        uint256 maxProposalAmount,
        uint256 minProposalAmount
    );

    event EmergencyMintExecuted(
        address indexed recipient,
        uint256 amount,
        string reason
    );

    // ============================================
    // CONSTRUCTOR & INITIALIZER
    // ============================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address governance,
        address guardian,
        address _andeToken,
        address _veANDE,
        uint256 _hardCap,
        uint256 _annualMintLimit
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Validate inputs
        if (_andeToken == address(0)) revert InvalidTokenAddress();
        if (_veANDE == address(0)) revert InvalidVeANDEAddress();
        if (defaultAdmin == address(0) || governance == address(0)) {
            revert InvalidParameters();
        }

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(GUARDIAN_ROLE, guardian);

        // Initialize token references
        andeToken = IMintable(_andeToken);
        veANDE = VeANDE(_veANDE);

        // Validate hard cap
        uint256 currentSupply = andeToken.totalSupply();
        if (_hardCap <= currentSupply) revert InvalidHardCap();

        // Set economic parameters
        hardCap = _hardCap;
        annualMintLimit = _annualMintLimit;
        lastMintYear = block.timestamp / (365 days);
        
        // Set default governance parameters
        quorumPercentage = 2000; // 20% quorum
        votingPeriod = 3 days;
        executionDelay = 2 days; // Timelock
        proposalLifetime = 14 days; // Proposals expire after 2 weeks
        
        // Set default proposal limits (10% of annual limit)
        maxProposalAmount = _annualMintLimit / 10;
        minProposalAmount = 1000 * 10**18; // 1000 tokens minimum
    }

    // ============================================
    // PROPOSAL CREATION
    // ============================================
    
    function createProposal(
        uint256 amount,
        address recipient,
        string calldata description
    ) external onlyRole(GOVERNANCE_ROLE) whenNotPaused returns (uint256) {
        // Validate inputs
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount < minProposalAmount) revert BelowMinProposalAmount();
        if (amount > maxProposalAmount) revert ExceedsMaxProposalAmount();

        // Pre-check limits (actual enforcement happens at execution)
        _checkMintFeasibility(amount);

        proposalCount++;
        uint256 proposalId = proposalCount;
        MintProposal storage proposal = proposals[proposalId];

        // Create snapshot for voting
        uint256 snapshotBlock = block.number - 1;
        uint256 totalVotingPower = veANDE.getPastTotalSupply(snapshotBlock);
        
        if (totalVotingPower == 0) revert NoVotingPower();

        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.snapshotBlock = snapshotBlock;
        proposal.creationTime = block.timestamp;
        proposal.votingDeadline = block.timestamp + votingPeriod;
        proposal.totalVotingPowerAtSnapshot = totalVotingPower;
        proposal.description = description;

        emit ProposalCreated(
            proposalId,
            amount,
            recipient,
            snapshotBlock,
            proposal.votingDeadline,
            description
        );

        return proposalId;
    }

    // ============================================
    // VOTING
    // ============================================
    
    function castVote(uint256 proposalId, bool support) external whenNotPaused {
        _castVote(proposalId, msg.sender, support);
    }

    function castVoteFor(
        uint256 proposalId,
        address voter,
        bool support
    ) external onlyRole(GOVERNANCE_ROLE) whenNotPaused {
        _castVote(proposalId, voter, support);
    }

    function _castVote(
        uint256 proposalId,
        address voter,
        bool support
    ) internal {
        MintProposal storage proposal = proposals[proposalId];
        
        // Validate proposal state
        if (proposal.creationTime == 0) revert ProposalNotFound();
        if (proposal.cancelled) revert ProposalIsCancelled();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (block.timestamp > proposal.votingDeadline) revert VotingPeriodEnded();
        if (proposal.hasVoted[voter]) revert AlreadyVoted();

        // Get voting power at snapshot
        uint256 voteWeight = veANDE.getPastVotes(voter, proposal.snapshotBlock);
        if (voteWeight == 0) revert NoVotingPower();

        // Record vote
        proposal.hasVoted[voter] = true;
        if (support) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        emit VoteCast(
            proposalId,
            voter,
            support,
            voteWeight,
            proposal.votesFor,
            proposal.votesAgainst
        );
    }

    // ============================================
    // PROPOSAL EXECUTION
    // ============================================
    
    function queueProposal(uint256 proposalId) external whenNotPaused {
        MintProposal storage proposal = proposals[proposalId];
        
        // Validate state
        ProposalState state = getProposalState(proposalId);
        if (state != ProposalState.Succeeded) revert ProposalNotSucceeded();
        if (block.timestamp <= proposal.votingDeadline) revert VotingPeriodNotEnded();

        // Set execution time (after timelock delay)
        proposal.executionETA = block.timestamp + executionDelay;

        emit ProposalQueued(proposalId, proposal.executionETA);
    }

    function executeProposal(uint256 proposalId)
        external
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused
        nonReentrant
    {
        MintProposal storage proposal = proposals[proposalId];
        
        // Validate state
        ProposalState state = getProposalState(proposalId);
        if (state != ProposalState.Queued) revert ProposalNotSucceeded();
        if (block.timestamp < proposal.executionETA) revert ProposalTimelockNotMet();

        // Check if proposal expired
        if (block.timestamp > proposal.creationTime + proposalLifetime) {
            proposal.cancelled = true;
            emit ProposalExpired(proposalId);
            revert ProposalHasExpired();
        }

        // Execute mint
        _mint(proposal.recipient, proposal.amount);

        proposal.executed = true;
        emit ProposalExecuted(proposalId, proposal.amount, proposal.recipient);
    }

    function cancelProposal(uint256 proposalId)
        external
        whenNotPaused
    {
        // Only governance or guardian can cancel
        if (!hasRole(GOVERNANCE_ROLE, msg.sender) && !hasRole(GUARDIAN_ROLE, msg.sender)) {
            revert InvalidParameters();
        }

        MintProposal storage proposal = proposals[proposalId];
        if (proposal.creationTime == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalIsCancelled();

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    // ============================================
    // MINTING LOGIC
    // ============================================
    
    function _mint(address to, uint256 amount) internal {
        // Check hard cap
        uint256 currentTotalSupply = andeToken.totalSupply();
        if (currentTotalSupply + amount > hardCap) {
            revert ExceedsHardCap();
        }

        // Check and update annual limit
        uint256 currentYear = block.timestamp / (365 days);
        if (currentYear > lastMintYear) {
            lastMintYear = currentYear;
            mintedThisYear = 0;
        }

        if (mintedThisYear + amount > annualMintLimit) {
            revert ExceedsAnnualLimit();
        }

        // Update state
        mintedThisYear += amount;
        totalMinted += amount;
        
        // Execute mint
        andeToken.mint(to, amount);
    }

    function _checkMintFeasibility(uint256 amount) internal view {
        // Check hard cap
        uint256 currentTotalSupply = andeToken.totalSupply();
        if (currentTotalSupply + amount > hardCap) {
            revert ExceedsHardCap();
        }

        // Check annual limit (considering current year)
        uint256 currentYear = block.timestamp / (365 days);
        uint256 availableThisYear = currentYear > lastMintYear
            ? annualMintLimit
            : annualMintLimit - mintedThisYear;

        if (amount > availableThisYear) {
            revert ExceedsAnnualLimit();
        }
    }

    // ============================================
    // EMERGENCY FUNCTIONS
    // ============================================
    
    function emergencyMint(
        address recipient,
        uint256 amount,
        string calldata reason
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();

        _mint(recipient, amount);
        
        emit EmergencyMintExecuted(recipient, amount, reason);
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        MintProposal storage proposal = proposals[proposalId];
        
        if (proposal.creationTime == 0) return ProposalState.Pending;
        if (proposal.cancelled) return ProposalState.Cancelled;
        if (proposal.executed) return ProposalState.Executed;
        
        // Check if expired
        if (block.timestamp > proposal.creationTime + proposalLifetime) {
            return ProposalState.Expired;
        }

        // Check if voting period active
        if (block.timestamp <= proposal.votingDeadline) {
            return ProposalState.Active;
        }

        // Voting ended, check results
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 quorum = (proposal.totalVotingPowerAtSnapshot * quorumPercentage) / BASIS_POINTS;
        
        // Check quorum
        if (totalVotes < quorum) {
            return ProposalState.Defeated;
        }

        // Check supermajority
        uint256 supportPercentage = (proposal.votesFor * BASIS_POINTS) / totalVotes;
        if (supportPercentage < SUPERMAJORITY_THRESHOLD) {
            return ProposalState.Defeated;
        }

        // Succeeded, check if queued
        if (proposal.executionETA > 0) {
            return ProposalState.Queued;
        }

        return ProposalState.Succeeded;
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getRemainingAnnualCapacity() external view returns (uint256) {
        uint256 currentYear = block.timestamp / (365 days);
        if (currentYear > lastMintYear) {
            return annualMintLimit;
        }
        return annualMintLimit - mintedThisYear;
    }

    function getRemainingHardCapCapacity() external view returns (uint256) {
        uint256 currentSupply = andeToken.totalSupply();
        return hardCap > currentSupply ? hardCap - currentSupply : 0;
    }

    function getProposalCore(uint256 proposalId)
        external
        view
        returns (
            uint256 amount,
            address recipient,
            string memory description
        )
    {
        MintProposal storage proposal = proposals[proposalId];
        return (
            proposal.amount,
            proposal.recipient,
            proposal.description
        );
    }

    function getProposalTimestamps(uint256 proposalId)
        external
        view
        returns (
            uint256 snapshotBlock,
            uint256 creationTime,
            uint256 votingDeadline,
            uint256 executionETA
        )
    {
        MintProposal storage proposal = proposals[proposalId];
        return (
            proposal.snapshotBlock,
            proposal.creationTime,
            proposal.votingDeadline,
            proposal.executionETA
        );
    }

    function getProposalVotes(uint256 proposalId)
        external
        view
        returns (
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 totalVotingPower
        )
    {
        MintProposal storage proposal = proposals[proposalId];
        return (
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.totalVotingPowerAtSnapshot
        );
    }

    function getProposalStatus(uint256 proposalId)
        external
        view
        returns (
            bool executed,
            bool cancelled,
            ProposalState state
        )
    {
        MintProposal storage proposal = proposals[proposalId];
        return (
            proposal.executed,
            proposal.cancelled,
            getProposalState(proposalId)
        );
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    function updateGovernanceParameters(
        uint256 _quorumPercentage,
        uint256 _votingPeriod,
        uint256 _executionDelay,
        uint256 _proposalLifetime
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_quorumPercentage > BASIS_POINTS) revert InvalidParameters();
        if (_votingPeriod < 1 days || _votingPeriod > 14 days) revert InvalidParameters();
        if (_executionDelay < 1 days || _executionDelay > 7 days) revert InvalidParameters();
        if (_proposalLifetime < 7 days) revert InvalidParameters();

        quorumPercentage = _quorumPercentage;
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
        proposalLifetime = _proposalLifetime;

        emit GovernanceParametersUpdated(
            _quorumPercentage,
            _votingPeriod,
            _executionDelay,
            _proposalLifetime
        );
    }

    function updateMintLimits(
        uint256 _annualMintLimit,
        uint256 _maxProposalAmount,
        uint256 _minProposalAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_maxProposalAmount > _annualMintLimit) revert InvalidParameters();
        if (_minProposalAmount > _maxProposalAmount) revert InvalidParameters();

        annualMintLimit = _annualMintLimit;
        maxProposalAmount = _maxProposalAmount;
        minProposalAmount = _minProposalAmount;

        emit MintLimitsUpdated(
            _annualMintLimit,
            _maxProposalAmount,
            _minProposalAmount
        );
    }

    function updateHardCap(uint256 _newHardCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newHardCap <= hardCap) revert InvalidParameters();
        if (_newHardCap <= andeToken.totalSupply()) revert InvalidHardCap();
        
        hardCap = _newHardCap;
    }

    // ============================================
    // UUPS UPGRADE
    // ============================================
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Additional upgrade validation could go here
    }
}