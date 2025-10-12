// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IEntryPoint
 * @notice Interface for ERC-4337 EntryPoint contract
 * @dev This interface defines the core functions that Claude needs to implement
 *      GLM has prepared this structure to facilitate Claude's implementation
 */

/**
 * @title UserOperation
 * @notice Standard ERC-4337 UserOperation structure
 */
struct UserOperation {
    address sender;              // The account contract
    uint256 nonce;
    bytes initCode;              // Account factory + calldata
    bytes callData;              // The call to execute
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;      // Paymaster address + data
    bytes signature;             // User signature
}

/**
 * @title UserOpResult
 * @notice Result of a UserOperation execution
 */
struct UserOpResult {
    uint256 paid;                // Total gas paid by user or paymaster
    uint256 actualGasCost;       // Actual gas cost
    bool success;                // Whether operation succeeded
    bytes returnData;            // Return data from the operation
}

interface IEntryPoint {
    // ========================================
    // EVENTS
    // ========================================

    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );

    event AccountDeployed(
        address indexed sender,
        address factory
    );

    event PrefundManagerWithdrawal(
        address indexed account,
        address indexed paymaster,
        uint256 amount
    );

    // ========================================
    // CORE FUNCTIONS (For Claude to implement)
    // ========================================

    /**
     * @notice Handle a bundle of UserOperations
     * @dev Main entry point for bundlers to execute UserOperations
     * @param ops Array of UserOperations to execute
     * @param beneficiary Address to receive gas fees
     */
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external;

    /**
     * @notice Simulate execution of a UserOperation (gas estimation)
     * @dev Returns estimated gas costs without modifying state
     * @param op UserOperation to simulate
     * @param targetOffset Offset in callData to target for simulation
     */
    function simulateHandleOp(
        UserOperation calldata op,
        address target,
        uint256 targetOffset
    ) external returns (uint256 preOpGas, bytes memory context, uint256 deadline);

    /**
     * @notice Get the counter for a sender account
     * @dev Used by wallets to construct valid UserOperations
     * @param sender Account address
     * @return nonce Current nonce for the account
     */
    function getNonce(address sender) external view returns (uint256 nonce);

    /**
     * @notice Get the deposit info for an account
     * @param depositInfo Address to check (account or paymaster)
     * @return deposit Current deposit amount
     * @return blockNumber Block when deposit was last updated
     */
    function depositInfo(address depositInfo)
        external
        view
        returns (uint256 deposit, uint256 blockNumber);

    /**
     * @notice Get the current sender address for creating a userOp
     * @dev Used during account creation process
     * @param initCode Account creation code
     * @return sender Address that will be created
     */
    function getSenderAddress(bytes memory initCode)
        external
        view
        returns (address sender);

    // ========================================
    // DEPOSIT/WITHDRAWAL FUNCTIONS
    // ========================================

    /**
     * @notice Add deposit to account or paymaster
     * @param account Address to add deposit to
     */
    function depositTo(address account) external payable;

    /**
     * @notice Withdraw deposit from account or paymaster
     * @param withdrawAddress Address to withdraw to
     * @param amount Amount to withdraw
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Get the current stake amount for an address
     * @param addr Address to check
     * @return stake Amount staked
     * @param unstakeDelaySec Delay before unstaking
     */
    function getStakeInfo(address addr)
        external
        view
        returns (uint256 stake, uint256 unstakeDelaySec);

    /**
     * @notice Check if an address is a trusted paymaster
     * @param paymaster Address to check
     * @return isTrusted Whether the paymaster is trusted
     */
    function isTrustedPaymaster(address paymaster)
        external
        view
        returns (bool isTrusted);
}

/**
 * @title IAccount
 * @notice Interface for smart contract accounts (wallets)
 */
interface IAccount {
    /**
     * @notice Validate UserOperation signature and nonce
     * @dev Must return 0 if valid, non-zero otherwise
     * @param userOp UserOperation to validate
     * @param userOpHash Hash of the UserOperation
     * @param missingAccountFunds Amount that account needs to pay
     * @return validationData 0 if valid, non-zero error code otherwise
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

/**
 * @title IPaymaster
 * @notice Interface for paymaster contracts
 */
interface IPaymaster {
    /**
     * @notice Validate paymaster data and deposit funds
     * @param userOp UserOperation to validate
     * @param userOpHash Hash of the UserOperation
     * @param maxCost Maximum gas cost this operation can cost
     * @return context Data to pass to postOp
     * @return validationData 0 if valid, non-zero error code otherwise
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * @notice Called after operation execution
     * @dev Used for final calculations and refunds
     * @param mode Execution mode
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;
}

/**
 * @title PostOpMode
 * @notice Mode for postOp execution
 */
enum PostOpMode {
    opSucceeded,     // Operation succeeded
    opReverted,      // Operation reverted
    postOpReverted   // postOp itself reverted
}