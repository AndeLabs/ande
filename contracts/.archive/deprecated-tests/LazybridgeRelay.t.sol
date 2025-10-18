// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/lazybridge/LazybridgeRelay.sol";
import "../../src/lazybridge/interfaces/ILazybridge.sol";
import "./mocks/MockZKVerifier.sol";
import "./mocks/MockCelestiaLightClient.sol";
import "../account/mocks/MockANDEToken.sol";

/**
 * @title LazybridgeRelay Test Suite
 * @notice Comprehensive tests for ZK-powered instant bridging
 * @dev Tests cover happy path, edge cases, and security scenarios
 */
contract LazybridgeRelayTest is Test {
    // ========================================
    // CONTRACTS
    // ========================================

    LazybridgeRelay public lazybridge;
    MockZKVerifier public zkVerifier;
    MockCelestiaLightClient public celestiaClient;
    MockANDEToken public andeToken;

    // ========================================
    // TEST ADDRESSES
    // ========================================

    address internal owner = address(0x1);
    address internal alice = address(0x2);
    address internal bob = address(0x3);
    address internal relayer = address(0x4);

    // ========================================
    // TEST CONSTANTS
    // ========================================

    uint256 internal SOURCE_CHAIN; // Will be set to block.chainid in setUp
    uint256 internal constant DEST_CHAIN = 2;
    uint256 internal constant BRIDGE_AMOUNT = 100 ether;

    // ========================================
    // SETUP
    // ========================================

    function setUp() public {
        // Set source chain to current chain ID
        SOURCE_CHAIN = block.chainid;

        vm.startPrank(owner);

        // Deploy mock contracts
        zkVerifier = new MockZKVerifier();
        celestiaClient = new MockCelestiaLightClient();
        andeToken = new MockANDEToken();

        // Deploy Lazybridge
        lazybridge = new LazybridgeRelay(
            address(zkVerifier),
            address(celestiaClient),
            owner
        );

        // Add ANDE token as supported
        lazybridge.addSupportedToken(address(andeToken));

        // Mint tokens to alice
        andeToken.mint(alice, 1000 ether);

        // Fund lazybridge for unlocks (simulating dest chain)
        andeToken.mint(address(lazybridge), 10000 ether);

        vm.stopPrank();
    }

    // ========================================
    // LOCK TESTS
    // ========================================

    function test_LockTokens() public {
        vm.startPrank(alice);

        // Approve lazybridge
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);

        // Lock tokens
        uint256 nonce = lazybridge.lock(
            address(andeToken),
            BRIDGE_AMOUNT,
            DEST_CHAIN,
            bob
        );

        vm.stopPrank();

        // Verify lock
        assertEq(nonce, 1, "First nonce should be 1");
        assertEq(andeToken.balanceOf(address(lazybridge)), 10000 ether + BRIDGE_AMOUNT, "Tokens should be locked");

        ILazybridge.BridgeLock memory lock = lazybridge.getLock(nonce);
        assertEq(lock.token, address(andeToken), "Token should match");
        assertEq(lock.amount, BRIDGE_AMOUNT, "Amount should match");
        assertEq(lock.sender, alice, "Sender should be alice");
        assertEq(lock.recipient, bob, "Recipient should be bob");
        assertEq(lock.sourceChainId, SOURCE_CHAIN, "Source chain should match");
        assertEq(lock.destChainId, DEST_CHAIN, "Dest chain should match");
    }

    function test_RevertLockUnsupportedToken() public {
        address unsupportedToken = address(0x9999);

        vm.startPrank(alice);

        vm.expectRevert(LazybridgeRelay.TokenNotSupported.selector);
        lazybridge.lock(unsupportedToken, BRIDGE_AMOUNT, DEST_CHAIN, bob);

        vm.stopPrank();
    }

    function test_RevertLockZeroAmount() public {
        vm.startPrank(alice);

        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);

        vm.expectRevert(LazybridgeRelay.InvalidAmount.selector);
        lazybridge.lock(address(andeToken), 0, DEST_CHAIN, bob);

        vm.stopPrank();
    }

    function test_RevertLockSameChain() public {
        vm.startPrank(alice);

        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);

        vm.expectRevert(LazybridgeRelay.InvalidChainId.selector);
        lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, SOURCE_CHAIN, bob);

        vm.stopPrank();
    }

    function test_MultipleLocks() public {
        vm.startPrank(alice);

        andeToken.approve(address(lazybridge), 300 ether);

        uint256 nonce1 = lazybridge.lock(address(andeToken), 100 ether, DEST_CHAIN, bob);
        uint256 nonce2 = lazybridge.lock(address(andeToken), 100 ether, DEST_CHAIN, bob);
        uint256 nonce3 = lazybridge.lock(address(andeToken), 100 ether, DEST_CHAIN, bob);

        vm.stopPrank();

        assertEq(nonce1, 1, "First nonce should be 1");
        assertEq(nonce2, 2, "Second nonce should be 2");
        assertEq(nonce3, 3, "Third nonce should be 3");
        assertEq(lazybridge.getCurrentNonce(), 4, "Next nonce should be 4");
    }

    // ========================================
    // RELAY TESTS
    // ========================================

    function test_RelayHappyPath() public {
        // 1. Alice locks tokens
        vm.startPrank(alice);
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);
        uint256 nonce = lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, DEST_CHAIN, bob);
        vm.stopPrank();

        // 2. Simulate Celestia block production
        bytes32 dataRoot = keccak256(abi.encodePacked("celestia_block", nonce));
        celestiaClient.advanceHeights(15); // Advance past min confirmations

        uint64 celestiaHeight = celestiaClient.getLatestHeight() - 12;
        celestiaClient.setDataRoot(celestiaHeight, dataRoot);

        // 3. Create ZK proof
        ILazybridge.BridgeLock memory lockData = lazybridge.getLock(nonce);

        uint256[] memory publicSignals = new uint256[](6);
        publicSignals[0] = uint256(uint160(lockData.token));
        publicSignals[1] = lockData.amount;
        publicSignals[2] = lockData.sourceChainId;
        publicSignals[3] = lockData.destChainId;
        publicSignals[4] = uint256(uint160(lockData.recipient));
        publicSignals[5] = lockData.nonce;

        bytes memory proof = zkVerifier.createMockProof();

        ILazybridge.ZKProof memory zkProof = ILazybridge.ZKProof({
            proof: proof,
            publicSignals: publicSignals,
            celestiaHeight: celestiaHeight,
            dataRoot: dataRoot
        });

        // 4. Create IBC packet
        bytes memory ibcPacket = celestiaClient.createMockIBCPacket(
            SOURCE_CHAIN,
            DEST_CHAIN,
            abi.encode(lockData)
        );

        // 5. DA proof
        bytes memory daProof = abi.encodePacked("da_proof", nonce);

        // 6. Relay
        uint256 bobBalanceBefore = andeToken.balanceOf(bob);

        vm.prank(relayer);
        lazybridge.relay(lockData, zkProof, ibcPacket, daProof);

        // Verify completion
        assertTrue(lazybridge.isCompleted(nonce), "Bridge should be completed");
        assertEq(
            andeToken.balanceOf(bob),
            bobBalanceBefore + BRIDGE_AMOUNT,
            "Bob should receive tokens"
        );
    }

    function test_RevertRelayInvalidZKProof() public {
        // 1. Lock tokens
        vm.startPrank(alice);
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);
        uint256 nonce = lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, DEST_CHAIN, bob);
        vm.stopPrank();

        // 2. Setup Celestia
        bytes32 dataRoot = keccak256(abi.encodePacked("celestia_block", nonce));
        celestiaClient.advanceHeights(15);
        uint64 celestiaHeight = celestiaClient.getLatestHeight() - 12;
        celestiaClient.setDataRoot(celestiaHeight, dataRoot);

        // 3. Create INVALID proof (wrong public signals)
        ILazybridge.BridgeLock memory lockData = lazybridge.getLock(nonce);

        uint256[] memory publicSignals = new uint256[](6);
        publicSignals[0] = uint256(uint160(lockData.token));
        publicSignals[1] = lockData.amount + 1; // WRONG AMOUNT
        publicSignals[2] = lockData.sourceChainId;
        publicSignals[3] = lockData.destChainId;
        publicSignals[4] = uint256(uint160(lockData.recipient));
        publicSignals[5] = lockData.nonce;

        bytes memory proof = zkVerifier.createMockProof();

        ILazybridge.ZKProof memory zkProof = ILazybridge.ZKProof({
            proof: proof,
            publicSignals: publicSignals,
            celestiaHeight: celestiaHeight,
            dataRoot: dataRoot
        });

        bytes memory ibcPacket = celestiaClient.createMockIBCPacket(SOURCE_CHAIN, DEST_CHAIN, abi.encode(lockData));
        bytes memory daProof = abi.encodePacked("da_proof", nonce);

        // 4. Should revert due to signal mismatch
        vm.prank(relayer);
        vm.expectRevert("Amount signal mismatch");
        lazybridge.relay(lockData, zkProof, ibcPacket, daProof);
    }

    function test_RevertRelayAlreadyCompleted() public {
        // 1. Complete a bridge
        test_RelayHappyPath();

        // 2. Try to relay again
        ILazybridge.BridgeLock memory lockData = lazybridge.getLock(1);

        uint256[] memory publicSignals = new uint256[](6);
        publicSignals[0] = uint256(uint160(lockData.token));
        publicSignals[1] = lockData.amount;
        publicSignals[2] = lockData.sourceChainId;
        publicSignals[3] = lockData.destChainId;
        publicSignals[4] = uint256(uint160(lockData.recipient));
        publicSignals[5] = lockData.nonce;

        bytes memory proof = zkVerifier.createMockProof();
        bytes32 dataRoot = keccak256(abi.encodePacked("celestia_block", uint256(1)));

        ILazybridge.ZKProof memory zkProof = ILazybridge.ZKProof({
            proof: proof,
            publicSignals: publicSignals,
            celestiaHeight: 1,
            dataRoot: dataRoot
        });

        bytes memory ibcPacket = celestiaClient.createMockIBCPacket(SOURCE_CHAIN, DEST_CHAIN, abi.encode(lockData));
        bytes memory daProof = abi.encodePacked("da_proof");

        vm.prank(relayer);
        vm.expectRevert(LazybridgeRelay.AlreadyCompleted.selector);
        lazybridge.relay(lockData, zkProof, ibcPacket, daProof);
    }

    // ========================================
    // EMERGENCY UNLOCK TESTS
    // ========================================

    function test_EmergencyUnlock() public {
        // 1. Lock tokens
        vm.startPrank(alice);
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);
        uint256 nonce = lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, DEST_CHAIN, bob);
        vm.stopPrank();

        uint256 aliceBalanceBefore = andeToken.balanceOf(alice);

        // 2. Advance time past timeout
        vm.warp(block.timestamp + 1 hours + 1);

        // 3. Emergency unlock
        vm.prank(alice);
        lazybridge.emergencyUnlock(nonce);

        // Verify
        assertTrue(lazybridge.isCompleted(nonce), "Should be marked completed");
        assertEq(
            andeToken.balanceOf(alice),
            aliceBalanceBefore + BRIDGE_AMOUNT,
            "Alice should get tokens back"
        );
    }

    function test_RevertEmergencyUnlockNotExpired() public {
        // 1. Lock tokens
        vm.startPrank(alice);
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);
        uint256 nonce = lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, DEST_CHAIN, bob);
        vm.stopPrank();

        // 2. Try to unlock immediately (not expired)
        vm.prank(alice);
        vm.expectRevert(LazybridgeRelay.BridgeNotExpired.selector);
        lazybridge.emergencyUnlock(nonce);
    }

    function test_RevertEmergencyUnlockUnauthorized() public {
        // 1. Lock tokens
        vm.startPrank(alice);
        andeToken.approve(address(lazybridge), BRIDGE_AMOUNT);
        uint256 nonce = lazybridge.lock(address(andeToken), BRIDGE_AMOUNT, DEST_CHAIN, bob);
        vm.stopPrank();

        // 2. Advance time
        vm.warp(block.timestamp + 1 hours + 1);

        // 3. Try to unlock as bob (not original sender)
        vm.prank(bob);
        vm.expectRevert(LazybridgeRelay.Unauthorized.selector);
        lazybridge.emergencyUnlock(nonce);
    }

    // ========================================
    // ADMIN TESTS
    // ========================================

    function test_AddSupportedToken() public {
        address newToken = address(0x1234);

        vm.prank(owner);
        lazybridge.addSupportedToken(newToken);

        assertTrue(lazybridge.isSupportedToken(newToken), "Token should be supported");
    }

    function test_RemoveSupportedToken() public {
        vm.prank(owner);
        lazybridge.removeSupportedToken(address(andeToken));

        assertFalse(lazybridge.isSupportedToken(address(andeToken)), "Token should not be supported");
    }

    function test_UpdateCelestiaClient() public {
        MockCelestiaLightClient newClient = new MockCelestiaLightClient();

        vm.prank(owner);
        lazybridge.updateCelestiaClient(address(newClient));

        assertEq(address(lazybridge.celestiaClient()), address(newClient), "Client should be updated");
    }

    function test_UpdateMinConfirmations() public {
        uint64 newMin = 20;

        vm.prank(owner);
        lazybridge.updateMinConfirmations(newMin);

        assertEq(lazybridge.minCelestiaConfirmations(), newMin, "Min confirmations should be updated");
    }

    // ========================================
    // VIEW FUNCTION TESTS
    // ========================================

    function test_GetBridgeStats() public {
        // 1. Lock and relay
        test_RelayHappyPath();

        // 2. Get stats
        (uint64 celestiaHeight, bool isComplete, uint256 timeElapsed) = lazybridge.getBridgeStats(1);

        assertTrue(isComplete, "Should be completed");
        assertGt(celestiaHeight, 0, "Should have Celestia height");
    }

    function test_IsSupportedToken() public view {
        assertTrue(lazybridge.isSupportedToken(address(andeToken)), "ANDE should be supported");
        assertFalse(lazybridge.isSupportedToken(address(0x9999)), "Random token should not be supported");
    }

    // ========================================
    // FUZZING TESTS
    // ========================================

    function testFuzz_LockVariousAmounts(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 ether);

        vm.startPrank(alice);

        andeToken.approve(address(lazybridge), amount);

        uint256 nonce = lazybridge.lock(address(andeToken), amount, DEST_CHAIN, bob);

        vm.stopPrank();

        ILazybridge.BridgeLock memory lock = lazybridge.getLock(nonce);
        assertEq(lock.amount, amount, "Amount should match fuzzed input");
    }

    function testFuzz_MultipleUsersLocking(address user, uint96 amount) public {
        vm.assume(user != address(0) && user != address(lazybridge));
        vm.assume(amount > 0);

        // Mint to user
        andeToken.mint(user, amount);

        vm.startPrank(user);

        andeToken.approve(address(lazybridge), amount);

        uint256 nonce = lazybridge.lock(address(andeToken), amount, DEST_CHAIN, bob);

        vm.stopPrank();

        ILazybridge.BridgeLock memory lock = lazybridge.getLock(nonce);
        assertEq(lock.sender, user, "Sender should be fuzzed user");
        assertEq(lock.amount, amount, "Amount should match");
    }
}
