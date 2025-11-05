// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeDisputeGameFactory} from "../src/fraud-proofs/AndeDisputeGameFactory.sol";
import {AndeFaultGame} from "../src/fraud-proofs/AndeFaultGame.sol";
import {IDisputeGame} from "../src/fraud-proofs/IDisputeGame.sol";

contract FraudProofsTest is Test {
    AndeDisputeGameFactory public factory;
    AndeFaultGame public faultGameImpl;
    
    address public owner;
    address public proposer;
    address public challenger;
    
    uint256 public constant BOND_AMOUNT = 0.1 ether;
    uint256 public constant MAX_GAME_DURATION = 7 days;
    uint64 public constant CHESS_CLOCK_DURATION = 3.5 days;
    uint64 public constant GLOBAL_DURATION = 7 days;
    uint256 public constant MIN_BOND = 0.1 ether;
    uint256 public constant MAX_BOND = 100 ether;

    bytes32 public constant ROOT_CLAIM = keccak256("root_claim");
    
    event DisputeGameCreated(
        address indexed gameProxy,
        AndeDisputeGameFactory.GameType indexed gameType,
        bytes32 indexed rootClaim,
        address creator
    );

    function setUp() public {
        owner = address(this);
        proposer = makeAddr("proposer");
        challenger = makeAddr("challenger");
        
        // Fund test accounts
        vm.deal(proposer, 100 ether);
        vm.deal(challenger, 100 ether);
        
        // Deploy contracts
        faultGameImpl = new AndeFaultGame();
        factory = new AndeDisputeGameFactory(owner, BOND_AMOUNT, MAX_GAME_DURATION);
        
        // Register game implementations
        factory.setGameImplementation(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            address(faultGameImpl)
        );
    }

    function testDeployment() public view {
        assertEq(factory.bondAmount(), BOND_AMOUNT);
        assertEq(factory.maxGameDuration(), MAX_GAME_DURATION);
        assertEq(factory.gameCount(), 0);
    }

    function testCreateGame() public {
        bytes memory extraData = abi.encode(
            CHESS_CLOCK_DURATION,
            GLOBAL_DURATION,
            MIN_BOND,
            MAX_BOND
        );

        vm.startPrank(proposer);
        
        vm.expectEmit(false, true, true, true);
        emit DisputeGameCreated(
            address(0), // We don't know the game address yet
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            ROOT_CLAIM,
            proposer
        );

        IDisputeGame game = factory.createGame{value: BOND_AMOUNT}(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            ROOT_CLAIM,
            extraData
        );

        vm.stopPrank();

        // Verify game state
        assertEq(uint8(game.status()), uint8(IDisputeGame.GameStatus.IN_PROGRESS));
        assertEq(game.rootClaim(), ROOT_CLAIM);
        assertEq(game.creator(), proposer);
        assertEq(factory.gameCount(), 1);
    }

    function testCannotCreateGameWithInsufficientBond() public {
        bytes memory extraData = abi.encode(
            CHESS_CLOCK_DURATION,
            GLOBAL_DURATION,
            MIN_BOND,
            MAX_BOND
        );

        vm.startPrank(proposer);
        
        vm.expectRevert("Insufficient bond");
        factory.createGame{value: 0.05 ether}(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            ROOT_CLAIM,
            extraData
        );

        vm.stopPrank();
    }

    function testAttackClaim() public {
        // Create game
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        // Attacker attacks root claim
        bytes32 attackClaim = keccak256("attack_claim");
        
        vm.startPrank(challenger);
        faultGame.attack{value: MIN_BOND}(0, attackClaim);
        vm.stopPrank();

        // Verify claim was added
        assertEq(faultGame.claimCount(), 2); // Root + attack
        
        AndeFaultGame.ClaimData memory claim = faultGame.getClaim(1);
        assertEq(claim.claim, attackClaim);
        assertEq(claim.claimant, challenger);
        assertEq(claim.parentIndex, 0);
    }

    function testDefendClaim() public {
        // Create game
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        // Defender defends root claim
        bytes32 defenseClaim = keccak256("defense_claim");
        
        vm.startPrank(proposer);
        faultGame.defend{value: MIN_BOND}(0, defenseClaim);
        vm.stopPrank();

        // Verify claim was added
        assertEq(faultGame.claimCount(), 2);
        
        AndeFaultGame.ClaimData memory claim = faultGame.getClaim(1);
        assertEq(claim.claim, defenseClaim);
        assertEq(claim.claimant, proposer);
        assertEq(claim.parentIndex, 0);
    }

    function testCannotAttackWithInsufficientBond() public {
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        bytes32 attackClaim = keccak256("attack_claim");
        
        vm.startPrank(challenger);
        vm.expectRevert("Insufficient bond");
        faultGame.attack{value: 0.05 ether}(0, attackClaim);
        vm.stopPrank();
    }

    function testBisectionGame() public {
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        // Level 1: Attack
        vm.startPrank(challenger);
        faultGame.attack{value: MIN_BOND}(0, keccak256("claim_1"));
        vm.stopPrank();

        // Level 2: Defend the attack
        vm.startPrank(proposer);
        faultGame.defend{value: _calculateBond(2)}(1, keccak256("claim_2"));
        vm.stopPrank();

        // Level 3: Attack the defense
        vm.startPrank(challenger);
        faultGame.attack{value: _calculateBond(3)}(2, keccak256("claim_3"));
        vm.stopPrank();

        assertEq(faultGame.claimCount(), 4); // Root + 3 moves
    }

    function testResolveUncontested() public {
        IDisputeGame game = _createGame();
        
        // Fast forward past chess clock duration
        vm.warp(block.timestamp + GLOBAL_DURATION + 1);

        // Resolve game
        game.resolve();

        // Defender wins since no one contested
        assertEq(uint8(game.status()), uint8(IDisputeGame.GameStatus.DEFENDER_WINS));
        assertTrue(game.resolvedAt() > 0);
    }

    function testResolveWithChallenge() public {
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        // Challenger attacks
        vm.startPrank(challenger);
        faultGame.attack{value: MIN_BOND}(0, keccak256("invalid_claim"));
        vm.stopPrank();

        // Fast forward
        vm.warp(block.timestamp + GLOBAL_DURATION + 1);

        // Resolve game
        game.resolve();

        // Game should be resolved
        assertTrue(uint8(game.status()) != uint8(IDisputeGame.GameStatus.IN_PROGRESS));
    }

    function testCannotResolveBeforeTime() public {
        IDisputeGame game = _createGame();
        
        vm.expectRevert("Cannot resolve yet");
        game.resolve();
    }

    function testCannotMoveAfterExpiry() public {
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        // Fast forward past game duration
        vm.warp(block.timestamp + GLOBAL_DURATION + 1);

        // Try to attack - should fail
        vm.startPrank(challenger);
        vm.expectRevert("Game expired");
        faultGame.attack{value: MIN_BOND}(0, keccak256("too_late"));
        vm.stopPrank();
    }

    function testBondScaling() public view {
        uint256 bond0 = _calculateBond(0);
        uint256 bond1 = _calculateBond(1);
        uint256 bond5 = _calculateBond(5);
        uint256 bond10 = _calculateBond(10);

        assertEq(bond0, MIN_BOND);
        assertGt(bond1, bond0);
        assertGt(bond5, bond1);
        assertGt(bond10, bond5);
    }

    function testMaxBondCap() public view {
        // At deep enough level, bond should cap at MAX_BOND
        uint256 deepBond = _calculateBond(100);
        assertEq(deepBond, MAX_BOND);
    }

    function testMultipleGames() public {
        bytes memory extraData = abi.encode(
            CHESS_CLOCK_DURATION,
            GLOBAL_DURATION,
            MIN_BOND,
            MAX_BOND
        );

        // Create multiple games
        vm.startPrank(proposer);
        
        IDisputeGame game1 = factory.createGame{value: BOND_AMOUNT}(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            keccak256("claim_1"),
            extraData
        );

        IDisputeGame game2 = factory.createGame{value: BOND_AMOUNT}(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            keccak256("claim_2"),
            extraData
        );

        vm.stopPrank();

        assertEq(factory.gameCount(), 2);
        assertTrue(address(game1) != address(game2));
    }

    function testGetGames() public {
        // Create several games
        _createMultipleGames(5);

        // Get all games
        IDisputeGame[] memory games = factory.getGames(0, 10);
        assertEq(games.length, 5);
    }

    function testGetGamesPagination() public {
        // Create many games
        _createMultipleGames(15);

        // Get first page
        IDisputeGame[] memory page1 = factory.getGames(0, 10);
        assertEq(page1.length, 10);

        // Get second page
        IDisputeGame[] memory page2 = factory.getGames(10, 10);
        assertEq(page2.length, 5);
    }

    function testUpdateBondAmount() public {
        uint256 newBond = 0.5 ether;
        factory.setBondAmount(newBond);
        assertEq(factory.bondAmount(), newBond);
    }

    function testUpdateMaxGameDuration() public {
        uint256 newDuration = 14 days;
        factory.setMaxGameDuration(newDuration);
        assertEq(factory.maxGameDuration(), newDuration);
    }

    function testOnlyOwnerCanSetImplementation() public {
        vm.startPrank(challenger);
        
        vm.expectRevert();
        factory.setGameImplementation(
            AndeDisputeGameFactory.GameType.VALIDITY_KECCAK,
            address(faultGameImpl)
        );
        
        vm.stopPrank();
    }

    // Helper functions

    function _createGame() internal returns (IDisputeGame) {
        bytes memory extraData = abi.encode(
            CHESS_CLOCK_DURATION,
            GLOBAL_DURATION,
            MIN_BOND,
            MAX_BOND
        );

        vm.startPrank(proposer);
        IDisputeGame game = factory.createGame{value: BOND_AMOUNT}(
            AndeDisputeGameFactory.GameType.FAULT_CANNON,
            ROOT_CLAIM,
            extraData
        );
        vm.stopPrank();

        return game;
    }

    function _createMultipleGames(uint256 count) internal {
        bytes memory extraData = abi.encode(
            CHESS_CLOCK_DURATION,
            GLOBAL_DURATION,
            MIN_BOND,
            MAX_BOND
        );

        vm.startPrank(proposer);
        for (uint256 i = 0; i < count; i++) {
            factory.createGame{value: BOND_AMOUNT}(
                AndeDisputeGameFactory.GameType.FAULT_CANNON,
                keccak256(abi.encodePacked("claim", i)),
                extraData
            );
        }
        vm.stopPrank();
    }

    function _calculateBond(uint256 depth) internal pure returns (uint256) {
        if (depth == 0) return MIN_BOND;
        
        uint256 bond = MIN_BOND;
        for (uint256 i = 0; i < depth; i++) {
            bond = (bond * 10893) / 10000;
            if (bond > MAX_BOND) return MAX_BOND;
        }
        
        return bond;
    }

    // Fuzz tests

    function testFuzz_AttackWithRandomClaim(bytes32 randomClaim) public {
        IDisputeGame game = _createGame();
        AndeFaultGame faultGame = AndeFaultGame(payable(address(game)));

        vm.startPrank(challenger);
        faultGame.attack{value: MIN_BOND}(0, randomClaim);
        vm.stopPrank();

        assertEq(faultGame.claimCount(), 2);
    }

    function testFuzz_BondAmount(uint256 bondAmount) public {
        bondAmount = bound(bondAmount, 0.01 ether, 1000 ether);
        
        factory.setBondAmount(bondAmount);
        assertEq(factory.bondAmount(), bondAmount);
    }
}
