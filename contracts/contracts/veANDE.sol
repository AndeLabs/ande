// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title VeANDE
 * @notice Vote-escrowed ANDE token for governance
 * @dev Implements time-locked voting power that decays linearly over time
 */
contract VeANDE is 
    Initializable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable, 
    IVotes, 
    EIP712Upgradeable, 
    NoncesUpgradeable 
{
    using SafeERC20 for IERC20;

    struct LockedBalance {
        uint256 amount;
        uint256 end;
    }

    struct Checkpoint {
        uint48 fromBlock;
        uint208 votes;
    }

    error InvalidAndeTokenAddress();
    error AmountNotPositive();
    error UnlockTimeNotInFuture();
    error CannotShortenLockTime();
    error LockDurationExceedsMax();
    error NoLockFound();
    error LockNotExpired();
    error BlockNotYetMined();

    IERC20 public andeToken;
    mapping(address => LockedBalance) public lockedBalances;

    mapping(address => Checkpoint[]) private _checkpoints;
    mapping(address => address) private _delegates;

    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;

    event LockCreated(address indexed user, uint256 amount, uint256 unlockTime);
    event LockIncreased(address indexed user, uint256 additionalAmount);
    event LockExtended(address indexed user, uint256 newUnlockTime);
    event Withdrawn(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address andeTokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __EIP712_init("veANDE", "1");
        __Nonces_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        if (andeTokenAddress == address(0)) revert InvalidAndeTokenAddress();
        andeToken = IERC20(andeTokenAddress);
    }

    // ============ Lock Management ============

    function createLock(uint256 amount, uint256 unlockTime) external {
        LockedBalance storage userLock = lockedBalances[msg.sender];

        if (userLock.amount == 0 && amount == 0) revert AmountNotPositive();
        if (unlockTime <= block.timestamp) revert UnlockTimeNotInFuture();
        if (userLock.amount > 0 && unlockTime < userLock.end) revert CannotShortenLockTime();

        uint256 lockDuration = unlockTime - block.timestamp;
        if (lockDuration > MAX_LOCK_TIME) revert LockDurationExceedsMax();

        uint256 oldVotingPower = balanceOf(msg.sender);

        if (amount > 0) {
            andeToken.safeTransferFrom(msg.sender, address(this), amount);
            userLock.amount += amount;
        }

        if (unlockTime > userLock.end) {
            userLock.end = unlockTime;
        }

        uint256 newVotingPower = balanceOf(msg.sender);

        // Update delegation
        address delegatee = _delegates[msg.sender];
        if (delegatee == address(0)) {
            delegatee = msg.sender;
            _delegates[msg.sender] = msg.sender;
        }

        if (newVotingPower > oldVotingPower) {
            _writeCheckpoint(delegatee, newVotingPower - oldVotingPower, true);
        } else if (oldVotingPower > newVotingPower) {
            _writeCheckpoint(delegatee, oldVotingPower - newVotingPower, false);
        }

        if (amount > 0 && userLock.amount == amount) {
            emit LockCreated(msg.sender, amount, unlockTime);
        } else if (amount > 0) {
            emit LockIncreased(msg.sender, amount);
        } else {
            emit LockExtended(msg.sender, unlockTime);
        }
    }

    function withdraw() external {
        LockedBalance storage userLock = lockedBalances[msg.sender];
        if (userLock.amount == 0) revert NoLockFound();
        if (block.timestamp < userLock.end) revert LockNotExpired();

        uint256 amount = userLock.amount;
        uint256 oldVotingPower = balanceOf(msg.sender);

        delete lockedBalances[msg.sender];

        // Update delegation
        address delegatee = _delegates[msg.sender];
        if (delegatee != address(0) && oldVotingPower > 0) {
            _writeCheckpoint(delegatee, oldVotingPower, false);
        }

        andeToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    // ============ Voting Power Calculation ============

    function balanceOf(address owner) public view returns (uint256) {
        LockedBalance storage userLock = lockedBalances[owner];
        if (userLock.amount == 0 || block.timestamp >= userLock.end) {
            return 0;
        }
        uint256 timeRemaining = userLock.end - block.timestamp;
        return (userLock.amount * timeRemaining) / MAX_LOCK_TIME;
    }

    // ============ IVotes Implementation ============

    function clock() public view virtual returns (uint48) {
        return uint48(block.number);
    }

    function CLOCK_MODE() public pure virtual returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    function getVotes(address account) public view override returns (uint256) {
        return _checkpoints[account].length == 0 
            ? 0 
            : _checkpoints[account][_checkpoints[account].length - 1].votes;
    }

    function getPastVotes(address account, uint256 timepoint) public view override returns (uint256) {
        uint48 currentClock = clock();
        if (timepoint >= currentClock) revert BlockNotYetMined();
        return _checkpointsLookup(account, uint48(timepoint));
    }

    function getPastTotalSupply(uint256 timepoint) public view virtual returns (uint256) {
        // veANDE doesn't track total supply in checkpoints
        // Return 0 as individual voting power is what matters
        timepoint; // silence warning
        return 0;
    }

    function delegates(address account) public view override returns (address) {
        address delegatee = _delegates[account];
        return delegatee == address(0) ? account : delegatee;
    }

    function delegate(address delegatee) public override {
        _delegate(msg.sender, delegatee);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        if (block.timestamp > expiry) {
            revert("VeANDE: expired deadline");
        }

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"),
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        address signatory = ECDSA.recover(digest, v, r, s);

        if (nonce != _useNonce(signatory)) {
            revert("VeANDE: invalid nonce");
        }

        _delegate(signatory, delegatee);
    }

    // ============ Internal Functions ============

    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate = _delegates[delegator];
        if (currentDelegate == address(0)) {
            currentDelegate = delegator;
        }

        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        // Move votes from old delegate to new delegate
        if (currentDelegate != delegatee && delegatorBalance > 0) {
            if (currentDelegate != address(0)) {
                _writeCheckpoint(currentDelegate, delegatorBalance, false);
            }
            if (delegatee != address(0)) {
                _writeCheckpoint(delegatee, delegatorBalance, true);
            }
        }
    }

    function _writeCheckpoint(
        address account,
        uint256 delta,
        bool increase
    ) internal {
        uint256 pos = _checkpoints[account].length;
        uint48 currentBlock = clock();

        uint208 oldVotes = pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
        uint208 newVotes = increase 
            ? oldVotes + uint208(delta)
            : oldVotes - uint208(delta);

        if (pos > 0 && _checkpoints[account][pos - 1].fromBlock == currentBlock) {
            _checkpoints[account][pos - 1].votes = newVotes;
        } else {
            _checkpoints[account].push(Checkpoint({
                fromBlock: currentBlock,
                votes: newVotes
            }));
        }

        emit DelegateVotesChanged(account, oldVotes, newVotes);
    }

    function _checkpointsLookup(address account, uint48 timepoint) internal view returns (uint256) {
        Checkpoint[] storage ckpts = _checkpoints[account];
        uint256 length = ckpts.length;

        if (length == 0) {
            return 0;
        }

        // Check most recent checkpoint
        if (ckpts[length - 1].fromBlock <= timepoint) {
            return ckpts[length - 1].votes;
        }

        // Check oldest checkpoint
        if (ckpts[0].fromBlock > timepoint) {
            return 0;
        }

        // Binary search
        uint256 low = 0;
        uint256 high = length - 1;

        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (ckpts[mid].fromBlock > timepoint) {
                high = mid - 1;
            } else {
                low = mid;
            }
        }

        return ckpts[low].votes;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {
        newImplementation; // silence warning
    }

    // ============ View Functions ============

    function getCheckpointCount(address account) external view returns (uint256) {
        return _checkpoints[account].length;
    }

    function getCheckpoint(address account, uint256 pos) external view returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }
}