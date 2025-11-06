// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDisputeGame} from "./IDisputeGame.sol";
import {AndeFaultGame} from "./AndeFaultGame.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibClone} from "@solady/utils/LibClone.sol";

/**
 * @title AndeDisputeGameFactory
 * @notice Factory contract for creating and managing dispute games
 * @dev Supports multiple game types for different proof systems
 */
contract AndeDisputeGameFactory is Ownable {
    /**
     * @notice Supported game types
     */
    enum GameType {
        FAULT_CANNON,      // Fault proof using Cannon (MIPS emulator)
        VALIDITY_KECCAK,   // Validity proof using Keccak preimage
        FAULT_ASTERISC     // Fault proof using Asterisc (RISC-V emulator)
    }

    /**
     * @notice Game implementation details
     */
    struct GameImplementation {
        address implementation;  // Implementation contract address
        bool initialized;        // Whether this game type is initialized
    }

    /**
     * @notice Emitted when a new game is created
     */
    event DisputeGameCreated(
        address indexed gameProxy,
        GameType indexed gameType,
        bytes32 indexed rootClaim,
        address creator
    );

    /**
     * @notice Emitted when a game implementation is set
     */
    event GameImplementationSet(GameType indexed gameType, address indexed implementation);

    /**
     * @notice Mapping of game type to implementation
     */
    mapping(GameType => GameImplementation) public gameImplementations;

    /**
     * @notice Array of all created games
     */
    IDisputeGame[] public games;

    /**
     * @notice Mapping from game address to game index
     */
    mapping(address => uint256) public gameIndex;

    /**
     * @notice Bond amount required to create a game (in wei)
     */
    uint256 public bondAmount;

    /**
     * @notice Maximum game duration (in seconds)
     */
    uint256 public maxGameDuration;

    constructor(address initialOwner, uint256 _bondAmount, uint256 _maxGameDuration) Ownable(initialOwner) {
        bondAmount = _bondAmount;
        maxGameDuration = _maxGameDuration;
    }

    /**
     * @notice Sets the implementation for a specific game type
     * @param gameType The type of game
     * @param implementation The implementation contract address
     */
    function setGameImplementation(GameType gameType, address implementation) external onlyOwner {
        require(implementation != address(0), "Invalid implementation");
        
        gameImplementations[gameType] = GameImplementation({
            implementation: implementation,
            initialized: true
        });

        emit GameImplementationSet(gameType, implementation);
    }

    /**
     * @notice Creates a new dispute game
     * @param gameType The type of game to create
     * @param rootClaim The root claim being disputed
     * @param extraData Extra data for the game (implementation specific)
     * @return game The created game instance
     */
    function createGame(
        GameType gameType,
        bytes32 rootClaim,
        bytes memory extraData
    ) external payable returns (IDisputeGame game) {
        require(msg.value >= bondAmount, "Insufficient bond");
        
        GameImplementation memory impl = gameImplementations[gameType];
        require(impl.initialized, "Game type not initialized");

        // Create clone of implementation
        address gameProxy = _deployClone(impl.implementation);
        
        // Initialize the game
        AndeFaultGame(payable(gameProxy)).initialize{value: msg.value}(
            rootClaim,
            msg.sender,
            extraData
        );

        game = IDisputeGame(gameProxy);

        // Store game reference
        gameIndex[gameProxy] = games.length;
        games.push(game);

        emit DisputeGameCreated(gameProxy, gameType, rootClaim, msg.sender);
    }

    /**
     * @notice Returns the total number of games created
     */
    function gameCount() external view returns (uint256) {
        return games.length;
    }

    /**
     * @notice Returns all games (paginated)
     * @param offset Starting index
     * @param limit Number of games to return
     */
    function getGames(uint256 offset, uint256 limit) 
        external 
        view 
        returns (IDisputeGame[] memory) 
    {
        require(offset < games.length, "Offset out of bounds");
        
        uint256 end = offset + limit;
        if (end > games.length) {
            end = games.length;
        }

        uint256 size = end - offset;
        IDisputeGame[] memory result = new IDisputeGame[](size);

        for (uint256 i = 0; i < size; i++) {
            result[i] = games[offset + i];
        }

        return result;
    }

    /**
     * @notice Updates the bond amount
     * @param newBondAmount New bond amount in wei
     */
    function setBondAmount(uint256 newBondAmount) external onlyOwner {
        bondAmount = newBondAmount;
    }

    /**
     * @notice Updates the maximum game duration
     * @param newMaxDuration New maximum duration in seconds
     */
    function setMaxGameDuration(uint256 newMaxDuration) external onlyOwner {
        maxGameDuration = newMaxDuration;
    }

    /**
     * @notice Deploys a minimal proxy clone
     * @param implementation The implementation contract to clone
     * @return instance The deployed clone address
     */
    function _deployClone(address implementation) internal returns (address instance) {
        // Use CREATE2 for deterministic deployment
        bytes32 salt = keccak256(abi.encodePacked(games.length, block.timestamp, msg.sender));
        
        assembly {
            // Load free memory pointer
            let ptr := mload(0x40)
            
            // Store clone bytecode
            // 0x3d602d80600a3d3981f3363d3d373d3d3d363d73 (20 bytes)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            
            // Store implementation address (20 bytes)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            
            // Store rest of bytecode
            // 0x5af43d82803e903d91602b57fd5bf3 (15 bytes)
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            
            // Deploy with CREATE2
            instance := create2(0, ptr, 0x37, salt)
        }
        
        require(instance != address(0), "Clone deployment failed");
    }
}
