// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {GovernorUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {AndeTimelockController} from "./AndeTimelockController.sol";
import {GovernorDualTokenVoting, IAndeNativeStaking} from "./extensions/GovernorDualTokenVoting.sol";
import {GovernorAdaptiveQuorum} from "./extensions/GovernorAdaptiveQuorum.sol";
import {GovernorMultiLevel} from "./extensions/GovernorMultiLevel.sol";
// import {GovernorSecurityExtensions} from "./extensions/GovernorSecurityExtensions.sol"; // TODO: Add via upgrade v2

/**
 * @title AndeGovernor
 * @author Ande Labs & Gemini
 * @notice The main governance contract for AndeChain.
 * @dev This contract manages proposals and voting. It is controlled by ANDE token holders.
 * 
 * ENHANCED FEATURES (v3.0):
 * - Dual Token Voting: Combines base token votes + staking bonus
 * - Users get bonus voting power based on their staking (lock period multipliers)
 * - Anti-whale protection: max 500% bonus over base votes + max 10% voting power cap
 * - Adaptive Quorum: Adjusts between 4-15% based on historical participation
 * - Multi-Level Proposals: 4 types (OPERATIONAL, PROTOCOL, CRITICAL, EMERGENCY)
 * - TimelockController for secure execution
 * 
 * NOTE: Security Extensions (anti-whale, rate limiting, guardian) will be added in v2 upgrade
 * - Upgradeable using UUPS pattern
 * 
 * VOTING POWER FORMULA:
 * totalVotes = baseVotes (from ANDETokenDuality) + stakingBonus (from AndeNativeStaking)
 * Capped at 10% of total supply per voter
 * 
 * QUORUM FORMULA:
 * - High participation (>20%) → quorum = 4%
 * - Low participation (<10%) → quorum = 15%
 * - Medium participation → linear interpolation
 * 
 * PROPOSAL TYPES:
 * - OPERATIONAL: 1M ANDE threshold, 3 days voting
 * - PROTOCOL: 5M ANDE threshold, 7 days voting
 * - CRITICAL: 10M ANDE threshold, 10 days voting
 * - EMERGENCY: Council only, 24 hours voting
 */
contract AndeGovernor is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorDualTokenVoting,
    GovernorAdaptiveQuorum,
    GovernorMultiLevel,
    GovernorTimelockControlUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Governor contract.
     * @param _token The address of the ANDE token (which implements IVotes).
     * @param _stakingContract The address of the AndeNativeStaking contract.
     * @param _timelock The address of the `AndeTimelockController`.
     * @param _votingPeriod The duration of the voting period in blocks.
     * @param _votingDelay The delay before a vote starts in blocks.
     * @param _proposalThreshold The minimum number of votes required to create a proposal.
     * @param _emergencyCouncil The address of the emergency council for EMERGENCY proposals.
     */
    function initialize(
        IVotes _token,
        IAndeNativeStaking _stakingContract,
        AndeTimelockController _timelock,
        uint32 _votingPeriod,
        uint48 _votingDelay,
        uint256 _proposalThreshold,
        address _emergencyCouncil
    ) public initializer {
        __Governor_init("AndeGovernor");
        __GovernorSettings_init(_votingDelay, _votingPeriod, _proposalThreshold);
        __GovernorDualTokenVoting_init(_token, _stakingContract);
        __GovernorAdaptiveQuorum_init();
        __GovernorMultiLevel_init(_emergencyCouncil);
        __GovernorTimelockControl_init(_timelock);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Grant DEFAULT_ADMIN_ROLE to the timelock (for upgrades)
        _grantRole(DEFAULT_ADMIN_ROLE, address(_timelock));
    }

    // --- Overrides for UUPS ---

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // --- Required Overrides ---

    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 timepoint)
        public
        view
        override(GovernorUpgradeable, GovernorAdaptiveQuorum)
        returns (uint256)
    {
        return GovernorAdaptiveQuorum.quorum(timepoint);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable, GovernorMultiLevel)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorAdaptiveQuorum, GovernorTimelockControlUpgradeable) {
        GovernorTimelockControlUpgradeable._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
        
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = _getProposalVotes(proposalId);
        _recordParticipation(proposalId, forVotes, againstVotes, abstainVotes);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorAdaptiveQuorum, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(GovernorUpgradeable, GovernorMultiLevel) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    function _isValidDescriptionForProposer(
        address proposer,
        string memory description
    ) internal view override(GovernorUpgradeable, GovernorMultiLevel) returns (bool) {
        return super._isValidDescriptionForProposer(proposer, description);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory params
    ) internal view override(GovernorUpgradeable, GovernorDualTokenVoting) returns (uint256) {
        return GovernorDualTokenVoting._getVotes(account, timepoint, params);
    }
    
    function _getTotalSupply(uint256 timepoint) 
        internal 
        view 
        override(GovernorAdaptiveQuorum, GovernorMultiLevel) 
        returns (uint256) 
    {
        return token().getPastTotalSupply(timepoint);
    }
    
    function _getProposalVotes(uint256 proposalId) internal view override returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
        (againstVotes, forVotes, abstainVotes) = proposalVotes(proposalId);
    }
    
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }
    
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override returns (uint256) {
        return super._castVote(proposalId, account, support, reason, params);
    }
    
    function proposalSnapshot(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorMultiLevel)
        returns (uint256)
    {
        return GovernorMultiLevel.proposalSnapshot(proposalId);
    }
    
    function proposalDeadline(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorMultiLevel)
        returns (uint256)
    {
        return GovernorMultiLevel.proposalDeadline(proposalId);
    }
}
