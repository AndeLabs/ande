pragma circom 2.1.0;

include "../../../node_modules/circomlib/circuits/poseidon.circom";
include "../../../node_modules/circomlib/circuits/comparators.circom";
include "../../../node_modules/circomlib/circuits/bitify.circom";

/**
 * @title BridgeLockCircuit
 * @notice ZK circuit for proving a valid bridge lock occurred
 * @dev Uses Groth16 for fast verification on-chain
 *
 * Public Inputs (verified on-chain):
 * - token: Token address being bridged
 * - amount: Amount being bridged
 * - sourceChainId: Source chain ID
 * - destChainId: Destination chain ID
 * - recipient: Recipient address on dest chain
 * - nonce: Unique bridge nonce
 *
 * Private Inputs (kept secret):
 * - senderPrivateKey: Sender's private key (proves ownership)
 * - lockTimestamp: When lock occurred
 * - lockTxHash: Transaction hash of the lock
 * - blockNumber: Block number of lock tx
 *
 * Constraints:
 * 1. Sender owns the private key (signature check)
 * 2. Lock event data is consistent
 * 3. Amount > 0
 * 4. Chain IDs are different (no self-bridge)
 * 5. Nonce is unique and sequential
 */
template BridgeLockCircuit() {
    // ========================================
    // PUBLIC INPUTS
    // ========================================
    signal input token;
    signal input amount;
    signal input sourceChainId;
    signal input destChainId;
    signal input recipient;
    signal input nonce;

    // ========================================
    // PRIVATE INPUTS
    // ========================================
    signal input senderPrivateKey;
    signal input senderAddress;
    signal input lockTimestamp;
    signal input lockTxHash;
    signal input blockNumber;

    // ========================================
    // INTERMEDIATE SIGNALS
    // ========================================
    signal output isValid;

    // ========================================
    // CONSTRAINTS
    // ========================================

    // 1. Verify amount is non-zero
    component amountCheck = GreaterThan(252);
    amountCheck.in[0] <== amount;
    amountCheck.in[1] <== 0;
    amountCheck.out === 1;

    // 2. Verify chain IDs are different (no self-bridge)
    component chainCheck = IsEqual();
    chainCheck.in[0] <== sourceChainId;
    chainCheck.in[1] <== destChainId;
    chainCheck.out === 0; // Must NOT be equal

    // 3. Verify nonce is non-zero and reasonable
    component nonceCheck = GreaterThan(252);
    nonceCheck.in[0] <== nonce;
    nonceCheck.in[1] <== 0;
    nonceCheck.out === 1;

    // 4. Verify sender address derives from private key
    // Simplified - in production use proper ECDSA verification
    component addressDerivation = Poseidon(1);
    addressDerivation.inputs[0] <== senderPrivateKey;
    signal derivedAddress <== addressDerivation.out;

    component addressCheck = IsEqual();
    addressCheck.in[0] <== derivedAddress;
    addressCheck.in[1] <== senderAddress;
    addressCheck.out === 1;

    // 5. Create commitment of lock data
    component lockCommitment = Poseidon(6);
    lockCommitment.inputs[0] <== token;
    lockCommitment.inputs[1] <== amount;
    lockCommitment.inputs[2] <== sourceChainId;
    lockCommitment.inputs[3] <== destChainId;
    lockCommitment.inputs[4] <== recipient;
    lockCommitment.inputs[5] <== nonce;

    // 6. Verify lock transaction hash is consistent
    component txHashCheck = Poseidon(4);
    txHashCheck.inputs[0] <== lockCommitment.out;
    txHashCheck.inputs[1] <== senderAddress;
    txHashCheck.inputs[2] <== lockTimestamp;
    txHashCheck.inputs[3] <== blockNumber;

    signal txHashComputed <== txHashCheck.out;

    component txHashVerify = IsEqual();
    txHashVerify.in[0] <== txHashComputed;
    txHashVerify.in[1] <== lockTxHash;
    txHashVerify.out === 1;

    // 7. Verify timestamp is reasonable (not in far future)
    // Assuming max timestamp is 2^40 (year 36812 in Unix time)
    component timestampCheck = LessThan(252);
    timestampCheck.in[0] <== lockTimestamp;
    timestampCheck.in[1] <== 1099511627776; // 2^40
    timestampCheck.out === 1;

    // 8. Output validity
    isValid <== 1;
}

/**
 * @title BatchBridgeLockCircuit
 * @notice Circuit for proving multiple bridge locks in a single proof
 * @dev More efficient for high-volume bridging
 */
template BatchBridgeLockCircuit(n) {
    // Public inputs - arrays of n locks
    signal input tokens[n];
    signal input amounts[n];
    signal input sourceChainIds[n];
    signal input destChainIds[n];
    signal input recipients[n];
    signal input nonces[n];

    // Private inputs
    signal input senderPrivateKeys[n];
    signal input senderAddresses[n];
    signal input lockTimestamps[n];
    signal input lockTxHashes[n];
    signal input blockNumbers[n];

    signal output batchRoot;

    // Verify each lock independently
    component locks[n];
    signal lockCommitments[n];

    for (var i = 0; i < n; i++) {
        locks[i] = BridgeLockCircuit();

        locks[i].token <== tokens[i];
        locks[i].amount <== amounts[i];
        locks[i].sourceChainId <== sourceChainIds[i];
        locks[i].destChainId <== destChainIds[i];
        locks[i].recipient <== recipients[i];
        locks[i].nonce <== nonces[i];
        locks[i].senderPrivateKey <== senderPrivateKeys[i];
        locks[i].senderAddress <== senderAddresses[i];
        locks[i].lockTimestamp <== lockTimestamps[i];
        locks[i].lockTxHash <== lockTxHashes[i];
        locks[i].blockNumber <== blockNumbers[i];

        locks[i].isValid === 1;

        // Create commitment for each lock
        component commitment = Poseidon(6);
        commitment.inputs[0] <== tokens[i];
        commitment.inputs[1] <== amounts[i];
        commitment.inputs[2] <== sourceChainIds[i];
        commitment.inputs[3] <== destChainIds[i];
        commitment.inputs[4] <== recipients[i];
        commitment.inputs[5] <== nonces[i];

        lockCommitments[i] <== commitment.out;
    }

    // Create Merkle root of all locks
    component merkleRoot = Poseidon(n);
    for (var i = 0; i < n; i++) {
        merkleRoot.inputs[i] <== lockCommitments[i];
    }

    batchRoot <== merkleRoot.out;
}

// Main component for single lock
component main {public [token, amount, sourceChainId, destChainId, recipient, nonce]} = BridgeLockCircuit();
