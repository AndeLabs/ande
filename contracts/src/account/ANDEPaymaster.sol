// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable reason-string */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BasePaymaster.sol";
import "./interfaces/IANDEPaymaster.sol";
import "./interfaces/IPriceOracle.sol";

/**
 * @title ANDEPaymaster
 * @notice Advanced paymaster for AndeChain that accepts ANDE tokens for gas payments
 * @dev Key improvements over TokenPaymaster:
 *      - Uses external ANDE token (not self-minted)
 *      - Dynamic price oracle integration for ANDE/ETH rates
 *      - Optional whitelist for sponsored transactions
 *      - Better security with SafeERC20
 *      - Configurable gas limits and fees
 */
contract ANDEPaymaster is BasePaymaster, IANDEPaymaster {
    using SafeERC20 for IERC20;

    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice ANDE token contract
    IERC20 public immutable andeToken;

    /// @notice Price oracle for ANDE/ETH conversion
    IPriceOracle public priceOracle;

    /// @notice Account factory (for validating account creation)
    address public immutable accountFactory;

    /// @notice Maximum gas this paymaster will sponsor per UserOp
    uint256 public maxGasLimit;

    /// @notice Whitelist for sponsored accounts (optional)
    mapping(address => bool) public whitelist;

    /// @notice Whether whitelist is enabled
    bool public whitelistEnabled;

    /// @notice Calculated cost of postOp execution
    uint256 public constant COST_OF_POST = 35000;

    /// @notice Price cache duration (to avoid expensive oracle calls)
    uint256 public constant PRICE_CACHE_DURATION = 60; // 1 minute

    /// @notice Cached ANDE/ETH price
    uint256 private cachedPrice;

    /// @notice Timestamp of cached price
    uint256 private cacheTimestamp;

    // ========================================
    // EVENTS
    // ========================================

    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event MaxGasLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event WhitelistStatusChanged(bool enabled);
    event UserOperationSponsored(address indexed sender, uint256 actualGasCost, uint256 andeCharge);

    // ========================================
    // ERRORS
    // ========================================

    error InvalidOracle();
    error InvalidToken();
    error InvalidFactory();
    error GasLimitTooHigh();
    error InsufficientANDEBalance();
    error InvalidConstructor();
    error NotWhitelisted();
    error TransferFailed();

    // ========================================
    // CONSTRUCTOR
    // ========================================

    /**
     * @notice Initialize ANDEPaymaster
     * @param _andeToken ANDE token address
     * @param _priceOracle Price oracle address
     * @param _accountFactory Account factory address
     * @param _entryPoint EntryPoint address
     * @param initialOwner Owner address
     */
    constructor(
        address _andeToken,
        IPriceOracle _priceOracle,
        address _accountFactory,
        IEntryPoint _entryPoint,
        address initialOwner
    ) BasePaymaster(_entryPoint) {
        if (_andeToken == address(0)) revert InvalidToken();
        if (address(_priceOracle) == address(0)) revert InvalidOracle();
        if (_accountFactory == address(0)) revert InvalidFactory();

        andeToken = IERC20(_andeToken);
        priceOracle = _priceOracle;
        accountFactory = _accountFactory;
        maxGasLimit = 1000000; // Default 1M gas

        // Transfer ownership
        _transferOwnership(initialOwner);
    }

    // ========================================
    // OWNER FUNCTIONS
    // ========================================

    /**
     * @notice Update price oracle
     * @param newOracle New oracle address
     */
    function setPriceOracle(IPriceOracle newOracle) external onlyOwner {
        if (address(newOracle) == address(0)) revert InvalidOracle();
        address oldOracle = address(priceOracle);
        priceOracle = newOracle;
        // Invalidate cache
        cacheTimestamp = 0;
        emit PriceOracleUpdated(oldOracle, address(newOracle));
    }

    /**
     * @notice Update maximum gas limit
     * @param newLimit New gas limit
     */
    function setMaxGasLimit(uint256 newLimit) external onlyOwner {
        uint256 oldLimit = maxGasLimit;
        maxGasLimit = newLimit;
        emit MaxGasLimitUpdated(oldLimit, newLimit);
    }

    /**
     * @notice Add address to whitelist
     * @param account Account to whitelist
     */
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
        emit WhitelistUpdated(account, true);
    }

    /**
     * @notice Remove address from whitelist
     * @param account Account to remove
     */
    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
        emit WhitelistUpdated(account, false);
    }

    /**
     * @notice Enable or disable whitelist
     * @param enabled Whether whitelist is enabled
     */
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistStatusChanged(enabled);
    }

    /**
     * @notice Withdraw ANDE tokens collected as fees
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawANDE(address to, uint256 amount) external onlyOwner {
        andeToken.safeTransfer(to, amount);
    }

    // ========================================
    // VIEW FUNCTIONS (IANDEPaymaster)
    // ========================================

    /// @inheritdoc IANDEPaymaster
    function getANDEToken() external view override returns (address) {
        return address(andeToken);
    }

    /// @inheritdoc IANDEPaymaster
    function getPriceOracle() external view override returns (address) {
        return address(priceOracle);
    }

    /// @inheritdoc IANDEPaymaster
    function getMaxGasLimit() external view override returns (uint256) {
        return maxGasLimit;
    }

    /// @inheritdoc IANDEPaymaster
    function isWhitelisted(address user) external view override returns (bool) {
        return whitelist[user];
    }

    /// @inheritdoc IANDEPaymaster
    function getCurrentExchangeRate() external view override returns (uint256) {
        return _getPrice();
    }

    /// @inheritdoc IANDEPaymaster
    function calculateANDECost(
        uint256 gasUsed,
        uint256 gasPrice
    ) external view override returns (uint256) {
        uint256 ethCost = gasUsed * gasPrice;
        return _getTokenValueOfEth(ethCost);
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================

    /**
     * @notice Validate paymaster UserOperation
     * @param userOp UserOperation to validate
     * @param userOpHash Hash of the UserOperation
     * @param requiredPreFund Required prefund in ETH
     * @return context Encoded context for postOp
     * @return validationData Validation result (0 = success)
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) internal override returns (bytes memory context, uint256 validationData) {
        // Check whitelist if enabled
        if (whitelistEnabled && !whitelist[userOp.sender]) {
            revert NotWhitelisted();
        }

        // Calculate ANDE token cost
        uint256 tokenPrefund = _getTokenValueOfEth(requiredPreFund);

        // Verify gas limits
        uint256 totalGas = userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        if (totalGas > maxGasLimit) revert GasLimitTooHigh();

        // Ensure verificationGasLimit is sufficient for postOp
        require(userOp.verificationGasLimit > COST_OF_POST, "ANDEPaymaster: gas too low for postOp");

        // If account creation, validate factory
        if (userOp.initCode.length != 0) {
            _validateConstructor(userOp);
        }

        // Check user has enough ANDE tokens
        uint256 userBalance = andeToken.balanceOf(userOp.sender);
        if (userBalance < tokenPrefund) revert InsufficientANDEBalance();

        // Encode context for postOp
        context = abi.encode(userOp.sender, tokenPrefund, userOpHash);

        // Return success
        return (context, 0);
    }

    /**
     * @notice Validate account constructor
     * @param userOp UserOperation with initCode
     */
    function _validateConstructor(UserOperation calldata userOp) internal view {
        address factory = address(bytes20(userOp.initCode[0:20]));
        if (factory != accountFactory) revert InvalidConstructor();
    }

    /**
     * @notice Execute post-operation actions (charge user)
     * @param mode Execution mode
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost in ETH
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        // Decode context
        (address sender, uint256 maxTokenCost, bytes32 userOpHash) = abi.decode(
            context,
            (address, uint256, bytes32)
        );

        // Calculate actual ANDE charge (including postOp cost)
        uint256 actualTokenCost = _getTokenValueOfEth(actualGasCost + COST_OF_POST);

        // Ensure we don't charge more than estimated
        if (actualTokenCost > maxTokenCost) {
            actualTokenCost = maxTokenCost;
        }

        // Transfer ANDE tokens from user to paymaster
        // Note: This assumes user has approved paymaster to spend ANDE
        // or we use permit-based approach
        andeToken.safeTransferFrom(sender, address(this), actualTokenCost);

        emit UserOperationSponsored(sender, actualGasCost, actualTokenCost);
    }

    /**
     * @notice Get ANDE/ETH price from oracle (with caching)
     * @return price ANDE tokens per 1 ETH (18 decimals)
     */
    function _getPrice() internal view returns (uint256 price) {
        // Use cached price if still valid (and cache has been set)
        if (cacheTimestamp > 0 && block.timestamp < cacheTimestamp + PRICE_CACHE_DURATION) {
            return cachedPrice;
        }

        // Fetch from oracle
        try priceOracle.getMedianPrice(address(andeToken)) returns (uint256 oraclePrice) {
            price = oraclePrice;
        } catch {
            // Fallback to cached price if oracle fails
            price = cachedPrice > 0 ? cachedPrice : 1e18; // Default 1:1 if no cache
        }

        return price;
    }

    /**
     * @notice Update price cache
     * @dev Called periodically or after oracle updates
     */
    function updatePriceCache() external {
        uint256 newPrice = _getPrice();
        cachedPrice = newPrice;
        cacheTimestamp = block.timestamp;
    }

    /**
     * @notice Convert ETH value to ANDE token value
     * @param ethValue Value in ETH (wei)
     * @return tokenValue Value in ANDE tokens (18 decimals)
     */
    function _getTokenValueOfEth(uint256 ethValue) internal view returns (uint256 tokenValue) {
        uint256 price = _getPrice(); // ANDE per ETH

        // If price is 2e18, it means 2 ANDE = 1 ETH
        // So for 1 ETH of gas, user needs to pay 2 ANDE
        tokenValue = (ethValue * price) / 1e18;

        return tokenValue;
    }
}
