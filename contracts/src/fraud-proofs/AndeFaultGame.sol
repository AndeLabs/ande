// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDisputeGame} from "./IDisputeGame.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AndeFaultGame
 * @notice Implements a bisection-based fault proof game
 * @dev Based on Optimism's FaultDisputeGame with AndeChain specific optimizations
 */
contract AndeFaultGame is IDisputeGame, Initializable {
    /**
     * @notice Represents a claim in the game tree
     */
    struct ClaimData {
        uint32 parentIndex;      // Index of parent claim
        address claimant;        // Address that made this claim
        uint128 bond;            // Bond amount for this claim
        bytes32 claim;           // The claim value (state root or execution trace)
        uint256 position;        // Position in the game tree
        uint256 clock;           // Chess clock (time remaining for this branch)
    }

    /**
     * @notice Chess clock configuration
     */
    struct ChessClock {
        uint64 duration;         // Total time allocated per player
        uint64 globalDuration;   // Global game duration
        uint64 startTime;        // Game start timestamp
    }

    /**
     * @notice Game constants
     */
    uint256 public constant MAX_GAME_DEPTH = 73;  // log2(8,388,608 instructions) + 1
    uint256 public constant SPLIT_DEPTH = 30;      // Depth at which to switch proof systems
    
    /**
     * @notice Game state
     */
    GameStatus public status;
    bytes32 public rootClaim;
    address public creator;
    uint256 public createdAt;
    uint256 public resolvedAt;
    bytes public extraData;
    
    /**
     * @notice Chess clock for time management
     */
    ChessClock public chessClock;

    /**
     * @notice All claims in the game
     */
    ClaimData[] public claims;

    /**
     * @notice Mapping of claim index to whether it has been countered
     */
    mapping(uint256 => bool) public claimCountered;

    /**
     * @notice Tracks resolved sub-games
     */
    mapping(uint256 => bool) public resolvedSubGames;

    /**
     * @notice Bond scaling factor (basis points, 10000 = 100%)
     */
    uint256 public constant BOND_SCALING_FACTOR = 10893; // ~1.0893x per level

    /**
     * @notice Minimum bond amount
     */
    uint256 public minBond;

    /**
     * @notice Maximum bond amount
     */
    uint256 public maxBond;

    /**
     * @notice Events
     */
    event ClaimAdded(uint256 indexed claimIndex, address indexed claimant, bytes32 claim);
    event StepExecuted(uint256 indexed claimIndex, bytes32 preState, bytes32 postState);

    /**
     * @notice Initializes the game
     * @param _rootClaim The root claim being disputed
     * @param _creator Address that created this game
     * @param _extraData Extra data for game configuration
     */
    function initialize(
        bytes32 _rootClaim,
        address _creator,
        bytes memory _extraData
    ) external payable initializer {
        rootClaim = _rootClaim;
        creator = _creator;
        createdAt = block.timestamp;
        extraData = _extraData;
        status = GameStatus.IN_PROGRESS;

        // Decode extra data for chess clock configuration
        (uint64 duration, uint64 globalDuration, uint256 _minBond, uint256 _maxBond) = 
            abi.decode(_extraData, (uint64, uint64, uint256, uint256));

        chessClock = ChessClock({
            duration: duration,
            globalDuration: globalDuration,
            startTime: uint64(block.timestamp)
        });

        // Default bonds in ANDE (native token of AndeChain)
        minBond = _minBond > 0 ? _minBond : 0.1 ether; // 0.1 ANDE
        maxBond = _maxBond > 0 ? _maxBond : 100 ether; // 100 ANDE

        // Add root claim as first claim
        claims.push(ClaimData({
            parentIndex: type(uint32).max,
            claimant: _creator,
            bond: uint128(msg.value),
            claim: _rootClaim,
            position: 1,  // Root position
            clock: duration
        }));

        emit ClaimAdded(0, _creator, _rootClaim);
    }

    /**
     * @notice Attacks a claim by providing a counter-claim
     * @param parentIndex Index of claim being attacked
     * @param claim The counter-claim
     */
    function attack(uint256 parentIndex, bytes32 claim) external payable {
        _move(parentIndex, claim, true);
    }

    /**
     * @notice Defends a claim by providing a supporting claim
     * @param parentIndex Index of claim being defended
     * @param claim The supporting claim
     */
    function defend(uint256 parentIndex, bytes32 claim) external payable {
        _move(parentIndex, claim, false);
    }

    /**
     * @notice Internal function to make a move (attack or defend)
     */
    function _move(uint256 parentIndex, bytes32 claim, bool isAttack) internal {
        require(status == GameStatus.IN_PROGRESS, "Game not in progress");
        require(parentIndex < claims.length, "Invalid parent index");
        require(!_isGameExpired(), "Game expired");

        ClaimData memory parent = claims[parentIndex];
        
        // Calculate new position in game tree
        uint256 nextPosition = isAttack 
            ? parent.position * 2      // Attack: left child
            : parent.position * 2 + 1; // Defend: right child

        // Check depth limit
        uint256 depth = _getDepth(nextPosition);
        require(depth <= MAX_GAME_DEPTH, "Max depth reached");

        // Calculate required bond (exponentially increasing)
        uint256 requiredBond = _calculateBond(depth);
        require(msg.value >= requiredBond, "Insufficient bond");

        // Update chess clock
        uint256 timeSinceLastMove = block.timestamp - createdAt;
        uint256 clockRemaining = parent.clock > timeSinceLastMove 
            ? parent.clock - timeSinceLastMove 
            : 0;
        require(clockRemaining > 0, "Clock expired");

        // Mark parent as countered
        claimCountered[parentIndex] = true;

        // Add new claim
        uint256 newIndex = claims.length;
        claims.push(ClaimData({
            parentIndex: uint32(parentIndex),
            claimant: msg.sender,
            bond: uint128(msg.value),
            claim: claim,
            position: nextPosition,
            clock: clockRemaining
        }));

        emit ClaimAdded(newIndex, msg.sender, claim);
        emit Move(newIndex, msg.sender, claim);
    }

    /**
     * @notice Executes a single instruction step to resolve a leaf dispute
     * @param claimIndex Index of the claim to step against
     * @param stateData The pre-state and proof data
     */
    function step(uint256 claimIndex, bytes calldata stateData) external {
        require(status == GameStatus.IN_PROGRESS, "Game not in progress");
        require(claimIndex < claims.length, "Invalid claim index");
        
        ClaimData memory claim = claims[claimIndex];
        
        // Must be at max depth to execute step
        uint256 depth = _getDepth(claim.position);
        require(depth == MAX_GAME_DEPTH, "Not at execution depth");

        // Decode state data
        (bytes32 preState, bytes memory proof) = abi.decode(stateData, (bytes32, bytes));

        // Execute single instruction and verify
        bytes32 postState = _executeInstruction(preState, proof);

        // Check if post-state matches claim
        if (postState == claim.claim) {
            // Claim is valid, mark as resolved
            resolvedSubGames[claimIndex] = true;
            
            // Defender wins this branch
            _resolveSubGame(claimIndex, claim.claimant);
        } else {
            // Claim is invalid, challenger wins
            resolvedSubGames[claimIndex] = true;
            _resolveSubGame(claimIndex, msg.sender);
        }

        emit StepExecuted(claimIndex, preState, postState);
    }

    /**
     * @notice Resolves the game and distributes bonds
     */
    function resolve() external {
        require(status == GameStatus.IN_PROGRESS, "Already resolved");
        require(_canResolve(), "Cannot resolve yet");

        // Walk the tree from root to determine winner
        bool rootValid = _resolveRecursive(0);

        if (rootValid) {
            status = GameStatus.DEFENDER_WINS;
            _distributeBonds(creator);
        } else {
            status = GameStatus.CHALLENGER_WINS;
            // Find the first challenger
            address challenger = claims.length > 1 ? claims[1].claimant : creator;
            _distributeBonds(challenger);
        }

        resolvedAt = block.timestamp;
        emit GameStatusChanged(status, msg.sender);
    }

    /**
     * @notice Recursively resolves the game tree
     */
    function _resolveRecursive(uint256 claimIndex) internal returns (bool) {
        // If already resolved, return cached result
        if (resolvedSubGames[claimIndex]) {
            return claims[claimIndex].claimant != address(0);
        }

        // If not countered, this claim stands
        if (!claimCountered[claimIndex]) {
            resolvedSubGames[claimIndex] = true;
            return true;
        }

        // Check children (attack and defense)
        ClaimData memory claim = claims[claimIndex];
        uint256 attackPos = claim.position * 2;
        uint256 defendPos = claim.position * 2 + 1;

        bool attackExists = false;
        bool defendExists = false;
        bool attackValid = false;
        bool defendValid = false;

        // Find children
        for (uint256 i = claimIndex + 1; i < claims.length; i++) {
            if (claims[i].position == attackPos) {
                attackExists = true;
                attackValid = !_resolveRecursive(i);  // Attack succeeds if it proves parent wrong
            } else if (claims[i].position == defendPos) {
                defendExists = true;
                defendValid = _resolveRecursive(i);   // Defense succeeds if it proves parent right
            }
        }

        // If attack succeeded, claim is invalid
        if (attackExists && attackValid) {
            resolvedSubGames[claimIndex] = true;
            return false;
        }

        // If defense succeeded, claim is valid
        if (defendExists && defendValid) {
            resolvedSubGames[claimIndex] = true;
            return true;
        }

        // Default: claim stands if not successfully countered
        resolvedSubGames[claimIndex] = true;
        return true;
    }

    /**
     * @notice Distributes bonds to the winner
     */
    function _distributeBonds(address winner) internal {
        uint256 totalBonds = 0;
        
        // Calculate total bonds
        for (uint256 i = 0; i < claims.length; i++) {
            totalBonds += claims[i].bond;
        }

        // Send to winner
        if (totalBonds > 0) {
            (bool success, ) = winner.call{value: totalBonds}("");
            require(success, "Bond transfer failed");
        }
    }

    /**
     * @notice Checks if the game can be resolved
     */
    function _canResolve() internal view returns (bool) {
        // Can resolve if global time limit reached
        if (block.timestamp >= createdAt + chessClock.globalDuration) {
            return true;
        }

        // Can resolve if all branches are resolved or expired
        for (uint256 i = 0; i < claims.length; i++) {
            if (!resolvedSubGames[i] && !claimCountered[i]) {
                uint256 claimAge = block.timestamp - createdAt;
                if (claimAge < claims[i].clock) {
                    return false;  // Still have time to counter
                }
            }
        }

        return true;
    }

    /**
     * @notice Checks if game has expired
     */
    function _isGameExpired() internal view returns (bool) {
        return block.timestamp >= createdAt + chessClock.globalDuration;
    }

    /**
     * @notice Calculates required bond for a given depth
     */
    function _calculateBond(uint256 depth) internal view returns (uint256) {
        if (depth == 0) return minBond;
        
        // Exponential scaling: bond = minBond * (BOND_SCALING_FACTOR/10000) ^ depth
        uint256 bond = minBond;
        for (uint256 i = 0; i < depth; i++) {
            bond = (bond * BOND_SCALING_FACTOR) / 10000;
            if (bond > maxBond) return maxBond;
        }
        
        return bond;
    }

    /**
     * @notice Calculates depth from position in tree
     */
    function _getDepth(uint256 position) internal pure returns (uint256) {
        uint256 depth = 0;
        uint256 pos = position;
        
        while (pos > 1) {
            pos = pos / 2;
            depth++;
        }
        
        return depth;
    }

    /**
     * @notice Executes a single instruction (placeholder for actual VM implementation)
     * @dev This should be replaced with actual Cannon/Asterisc execution
     */
    function _executeInstruction(bytes32 preState, bytes memory proof) 
        internal 
        pure 
        returns (bytes32) 
    {
        // TODO: Implement actual instruction execution
        // This would involve:
        // 1. Deserialize preState
        // 2. Execute one instruction using proof
        // 3. Serialize and return postState
        
        // Placeholder implementation
        return keccak256(abi.encodePacked(preState, proof));
    }

    /**
     * @notice Resolves a sub-game in favor of a winner
     */
    function _resolveSubGame(uint256 claimIndex, address winner) internal {
        resolvedSubGames[claimIndex] = true;
        // Additional resolution logic can be added here
    }

    /**
     * @notice Returns the game type
     */
    function gameType() external pure override returns (uint8) {
        return 0; // FAULT_CANNON
    }

    /**
     * @notice Returns the number of claims
     */
    function claimCount() external view returns (uint256) {
        return claims.length;
    }

    /**
     * @notice Returns claim data for a specific index
     */
    function getClaim(uint256 index) 
        external 
        view 
        returns (ClaimData memory) 
    {
        require(index < claims.length, "Invalid index");
        return claims[index];
    }
}
