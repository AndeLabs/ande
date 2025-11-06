// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeChainBridge} from "../../src/bridge/AndeChainBridge.sol";
import {IBlobstream} from "../../src/bridge/IBlobstream.sol";
import {IXERC20} from "../../src/interfaces/IXERC20.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

// ==================== Mock Contracts ====================

contract MockBlobstreamVerifier is IBlobstream {
    bool private _shouldSucceed;

    function setShouldSucceed(bool shouldSucceed) external {
        _shouldSucceed = shouldSucceed;
    }

    function verifyAttestation(
        bytes32, // txHash
        uint256, // sourceChain
        bytes calldata, // proof
        uint256 // minConfirmations
    ) external view returns (bool) {
        return _shouldSucceed;
    }
}

// ==================== Test Contract ====================

contract AndeChainBridgeTest is Test {
    // ==================== State Variables ====================

    AndeChainBridge internal bridge;
    MockBlobstreamVerifier internal mockVerifier;
    MockERC20 internal mockToken;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");

    uint256 internal constant DESTINATION_CHAIN_ID = 2;
    uint256 internal constant SOURCE_CHAIN_ID = 1;
    uint256 internal constant FORCE_INCLUSION_PERIOD = 1 days;

    // ==================== Setup ====================

    function setUp() public {
        // Deploy Mocks
        mockVerifier = new MockBlobstreamVerifier();
        mockToken = new MockERC20("Mock Token", "MTK", 18);

        // Deploy Bridge
        vm.prank(owner);
        bridge = new AndeChainBridge(owner, address(mockVerifier), 10, FORCE_INCLUSION_PERIOD);

        // Configure Bridge
        vm.prank(owner);
        bridge.addSupportedToken(address(mockToken));

        vm.prank(owner);
        bridge.setDestinationBridge(DESTINATION_CHAIN_ID, address(0xdeadbeef)); // Dummy address

        // Fund user
        mockToken.mint(user, 1_000_000 * 1e18);
    }

    // ==================== Test Functions ====================

    function test_ForceTransaction_Success() public {
        // 1. User initiates a bridge transaction
        uint256 bridgeAmount = 100 * 1e18;
        vm.startPrank(user);
        mockToken.approve(address(bridge), bridgeAmount);
        bridge.bridgeTokens(address(mockToken), recipient, bridgeAmount, DESTINATION_CHAIN_ID);
        vm.stopPrank();

        // 2. Relayer does not process it. Time passes beyond the force inclusion period.
        vm.warp(block.timestamp + FORCE_INCLUSION_PERIOD + 1);

        // 3. User prepares to force the transaction
        bytes32 txHash = keccak256(abi.encodePacked(user, recipient, bridgeAmount, block.timestamp));

        AndeChainBridge.BridgeTransaction memory txData = AndeChainBridge.BridgeTransaction({
            token: address(mockToken),
            recipient: recipient,
            amount: bridgeAmount,
            sourceChain: SOURCE_CHAIN_ID,
            sourceTxHash: txHash,
            blockTimestamp: block.timestamp - (FORCE_INCLUSION_PERIOD + 1) // Simulate original timestamp
        });

        // 4. Configure mock verifier to return true for the proof
        mockVerifier.setShouldSucceed(true);

        // 5. User calls forceTransaction
        // No prank needed, anyone can call it
        bridge.forceTransaction(txData, "0x"); // Proof is not validated by mock

        // 6. Assert that the recipient received the tokens
        assertEq(mockToken.balanceOf(recipient), bridgeAmount, "Recipient should have received the bridged tokens");
        assertTrue(bridge.isTransactionProcessed(txHash), "Transaction should be marked as processed");
    }
}
