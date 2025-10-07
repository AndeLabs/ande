// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {XERC20} from "./xERC20/XERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Interfaces for integration
interface IPriceOracle {
    function getMedianPrice(address token) external view returns (uint256 price);
}

interface ICollateralManager {
    function getCollateralInfo(address token) external view returns (
        bool isSupported,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling
    );
    function getPriceOracle(address token) external view returns (address oracle);
    function addCollateral(
        address token,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling,
        uint256 minCollateralAmount,
        address oracle
    ) external;
    function getSupportedCollaterals() external view returns (address[] memory tokens);
}

interface IAuctionManager {
    function startLiquidationAuction(
        address vaultOwner,
        address collateralToken,
        uint256 collateralAmount,
        uint256 totalDebt
    ) external returns (uint256 auctionId);
}

/**
 * @title AbobToken
 * @notice CDP (Collateralized Debt Position) vault manager for ABOB token
 * @dev Allows users to deposit collateral and mint ABOB against it
 * @dev Manages liquidations and system stability
 */
contract AbobToken is
    XERC20,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== ROLES ====================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LIQUIDATION_MANAGER_ROLE = keccak256("LIQUIDATION_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // ==================== CUSTOM ERRORS ====================
    error InsufficientCollateral();
    error UndercollateralizedPosition();
    error CollateralNotSupported();
    error LiquidationThresholdNotMet();
    error InvalidAmount();
    error ZeroAddress();
    error PositionDoesNotExist();
    error AlreadyLiquidated();
    error SystemNotStable();
    error TransferFailed();
    error AuctionNotActive();
    error InvalidCollateralType();
    error DebtCeilingExceeded();

    // ==================== CONSTANTS ====================
    uint256 private constant BASIS_POINTS = 10000; // 100% in basis points
    uint256 private constant MIN_HEALTH_FACTOR = 10000; // 100% health factor minimum
    uint256 private constant LIQUIDATION_PENALTY = 1050; // 5% liquidation penalty
    uint256 private constant MIN_AUCTION_DURATION = 1 hours;
    uint256 private constant MAX_AUCTION_DURATION = 24 hours;
    uint256 private constant GLOBAL_DEBT_CEILING = 100_000_000 * 1e18; // 100M ABOB max

    // ==================== STRUCTS ====================
    struct UserVault {
        mapping(address => uint256) collateralAmounts; // collateral token => amount
        mapping(address => uint256) lastCollateralUpdate; // timestamp for each collateral
        uint256 totalDebt; // ABOB debt
        uint256 lastInteraction; // timestamp of last interaction
        bool isActive; // whether the vault is active
    }

    struct CollateralInfo {
        bool isSupported;
        uint256 collateralRatio; // Required collateral ratio in basis points (e.g., 15000 = 150%)
        uint256 liquidationThreshold; // Liquidation threshold in basis points (e.g., 12500 = 125%)
        uint256 debtCeiling; // Maximum debt that can be minted with this collateral
        uint256 minDeposit; // Minimum deposit amount
        uint256 totalDeposited; // Total amount deposited across all vaults
        address priceOracle; // Oracle for price feeds
    }

    struct AuctionInfo {
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        uint256 reservePrice;
        address collateralToken;
        uint256 collateralAmount;
        uint256 debtToCover;
        address liquidator;
        bool isActive;
    }

    // ==================== STATE VARIABLES ====================

    // Governance
    address public governance;
    address public pendingGovernance;
    uint256 public governanceTransferDelay;
    uint256 public governanceTransferInitiated;

    // Price Oracle
    address public priceOracle;

    // Collateral Manager
    address public collateralManager;

    // Liquidation Manager
    address public liquidationManager;

    // System Configuration
    uint256 public globalDebtCeiling;
    uint256 public totalSystemDebt;
    uint256 public redemptionFee;
    uint256 public minRedemptionAmount;
    uint256 public redemptionCooldown;

    // User Vaults
    mapping(address => UserVault) public vaults;
    address[] public vaultUsers;

    // Supported Collaterals
    mapping(address => CollateralInfo) public supportedCollaterals;
    address[] public collateralList;

    // Liquidation Auctions
    mapping(uint256 => AuctionInfo) public auctions;
    uint256 public nextAuctionId;
    mapping(address => uint256[]) public userAuctions; // user => auctionIds

    // Stability Metrics
    uint256 public stabilityFeeRate;
    uint256 public lastStabilityFeeCollection;
    uint256 public stabilityFeeAccumulator;

    // Emergency Mechanisms
    bool public emergencyMode;
    uint256 public emergencyMintingCap;
    uint256 public emergencyMinted;

    // Migration Support
    bool public migrationEnabled;
    address public migrationTarget;
    mapping(address => bool) public hasMigrated;

    // ==================== EVENTS ====================
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed collateral, uint256 amount);
    event AbobMinted(address indexed user, uint256 amount);
    event AbobBurned(address indexed user, uint256 amount);
    event LiquidationTriggered(address indexed user, address indexed liquidator, uint256 debtCovered, uint256 collateralLiquidated);
    event AuctionCreated(uint256 indexed auctionId, address indexed user, address indexed collateral, uint256 amount, uint256 startPrice);
    event AuctionSettled(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);
    event GovernanceTransferInitiated(address indexed from, address indexed to);
    event GovernanceTransferred(address indexed from, address indexed to);
    event CollateralAdded(address indexed collateral, uint256 ratio, uint256 threshold, uint256 ceiling);
    event CollateralUpdated(address indexed collateral, uint256 ratio, uint256 threshold, uint256 ceiling);
    event CollateralRemoved(address indexed collateral);
    event StabilityFeeCollected(uint256 amount);
    event EmergencyModeToggled(bool enabled);
    event Redemption(address indexed user, uint256 abobAmount, address[] collateralTokens, uint256[] collateralAmounts);
    event Migration(address indexed user, address indexed target, uint256 amount);

    // ==================== MODIFIERS ====================
    modifier onlyGovernance() {
        require(hasRole(GOVERNANCE_ROLE, msg.sender), "Only governance");
        _;
    }

    modifier onlyLiquidationManager() {
        require(hasRole(LIQUIDATION_MANAGER_ROLE, msg.sender), "Only liquidation manager");
        _;
    }

    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "Only pauser");
        _;
    }

    modifier validCollateral(address _collateral) {
        bool isSupported;
        if (collateralManager != address(0)) {
            // Use CollateralManager if available
            (isSupported,,, ) = ICollateralManager(collateralManager).getCollateralInfo(_collateral);
        } else {
            // Fallback to local storage
            isSupported = supportedCollaterals[_collateral].isSupported;
        }
        require(isSupported, "Unsupported collateral");
        _;
    }

    modifier notEmergency() {
        require(!emergencyMode, "Emergency mode active");
        _;
    }

  
    modifier validVault(address _user) {
        require(vaults[_user].isActive, "Vault not active");
        _;
    }

    // ==================== INITIALIZATION ====================
    function initialize(
        address _admin,
        address _pauser,
        address _governance,
        address _priceOracle,
        address _collateralManager,
        address _liquidationManager
    ) external initializer {
        // Initialize XERC20 parent contract
        __ERC20_init("Andean Boliviano", "ABOB");
        __ERC20Permit_init("Andean Boliviano");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _governance);
        _grantRole(LIQUIDATION_MANAGER_ROLE, _liquidationManager);
        _grantRole(BRIDGE_MANAGER_ROLE, _admin); // For xERC20 functionality

        // Initialize state
        governance = _governance;
        priceOracle = _priceOracle;
        collateralManager = _collateralManager;
        liquidationManager = _liquidationManager;

        globalDebtCeiling = GLOBAL_DEBT_CEILING;
        redemptionFee = 50; // 0.5% redemption fee
        minRedemptionAmount = 100 * 1e18; // 100 ABOB minimum
        redemptionCooldown = 1 hours;

        stabilityFeeRate = 100; // 1% annual stability fee
        lastStabilityFeeCollection = block.timestamp;

        emergencyMintingCap = 1_000_000 * 1e18; // 1M ABOB emergency cap

        governanceTransferDelay = 7 days;
    }

    // ==================== COLLATERAL MANAGEMENT ====================

    /**
     * @notice Add a new supported collateral type (delegates to CollateralManager)
     * @param _collateral Address of the collateral token
     * @param _ratio Required collateral ratio in basis points
     * @param _threshold Liquidation threshold in basis points
     * @param _ceiling Maximum debt ceiling
     * @param _minDeposit Minimum deposit amount
     * @param _priceOracle Oracle for price feeds
     */
    function addCollateral(
        address _collateral,
        uint256 _ratio,
        uint256 _threshold,
        uint256 _ceiling,
        uint256 _minDeposit,
        address _priceOracle
    ) external onlyGovernance {
        if (collateralManager != address(0)) {
            // Delegate to CollateralManager if available
            ICollateralManager(collateralManager).addCollateral(_collateral, _ratio, _threshold, _ceiling, _minDeposit, _priceOracle);
        } else {
            // Fallback for backwards compatibility
            require(_collateral != address(0), "Invalid collateral address");
            require(_ratio > _threshold, "Ratio must be > threshold");
            require(_ratio <= 20000, "Ratio too high"); // Max 200%
            require(_threshold >= 10000, "Threshold too low"); // Min 100%
            require(!supportedCollaterals[_collateral].isSupported, "Already supported");

            supportedCollaterals[_collateral] = CollateralInfo({
                isSupported: true,
                collateralRatio: _ratio,
                liquidationThreshold: _threshold,
                debtCeiling: _ceiling,
                minDeposit: _minDeposit,
                totalDeposited: 0,
                priceOracle: _priceOracle
            });

            collateralList.push(_collateral);
            emit CollateralAdded(_collateral, _ratio, _threshold, _ceiling);
        }
    }

    /**
     * @notice Update collateral parameters
     */
    function updateCollateral(
        address _collateral,
        uint256 _ratio,
        uint256 _threshold,
        uint256 _ceiling,
        uint256 _minDeposit
    ) external onlyGovernance {
        require(supportedCollaterals[_collateral].isSupported, "Not supported");
        require(_ratio > _threshold, "Ratio must be > threshold");
        require(_ratio <= 20000, "Ratio too high");
        require(_threshold >= 10000, "Threshold too low");

        supportedCollaterals[_collateral].collateralRatio = _ratio;
        supportedCollaterals[_collateral].liquidationThreshold = _threshold;
        supportedCollaterals[_collateral].debtCeiling = _ceiling;
        supportedCollaterals[_collateral].minDeposit = _minDeposit;

        emit CollateralUpdated(_collateral, _ratio, _threshold, _ceiling);
    }

    /**
     * @notice Remove collateral support
     */
    function removeCollateral(address _collateral) external onlyGovernance {
        require(supportedCollaterals[_collateral].isSupported, "Not supported");
        require(supportedCollaterals[_collateral].totalDeposited == 0, "Collateral in use");

        // Remove from supported collaterals
        supportedCollaterals[_collateral].isSupported = false;

        // Remove from collateral list
        for (uint256 i = 0; i < collateralList.length; i++) {
            if (collateralList[i] == _collateral) {
                collateralList[i] = collateralList[collateralList.length - 1];
                collateralList.pop();
                break;
            }
        }

        emit CollateralRemoved(_collateral);
    }

    // ==================== VAULT OPERATIONS ====================

    /**
     * @notice Deposit collateral and mint ABOB in one transaction
     * @param _collateral Address of collateral token
     * @param _collateralAmount Amount of collateral to deposit
     * @param _abobAmount Amount of ABOB to mint
     */
    function depositCollateralAndMint(
        address _collateral,
        uint256 _collateralAmount,
        uint256 _abobAmount
    ) external whenNotPaused nonReentrant validCollateral(_collateral) {
        require(_collateralAmount > 0 && _abobAmount > 0, "Invalid amounts");
        require(_collateralAmount >= supportedCollaterals[_collateral].minDeposit, "Below minimum deposit");

        UserVault storage vault = vaults[msg.sender];

        // Initialize vault if new
        if (!vault.isActive) {
            vault.isActive = true;
            vault.lastInteraction = block.timestamp;
            vaultUsers.push(msg.sender);
        }

        // Check system debt ceiling
        require(totalSystemDebt + _abobAmount <= globalDebtCeiling, "System debt ceiling exceeded");

        // Get collateral info from CollateralManager or fallback to local
        uint256 collateralRatio;
        uint256 debtCeiling;
        if (collateralManager != address(0)) {
            (,uint256 ratio,, uint256 ceiling) = ICollateralManager(collateralManager).getCollateralInfo(_collateral);
            collateralRatio = ratio;
            debtCeiling = ceiling;
        } else {
            collateralRatio = supportedCollaterals[_collateral].collateralRatio;
            debtCeiling = supportedCollaterals[_collateral].debtCeiling;
        }

        // Check collateral-specific debt ceiling
        uint256 collateralDebt = getCollateralDebt(_collateral);
        require(collateralDebt + _abobAmount <= debtCeiling, "Collateral debt ceiling exceeded");

        // Calculate required collateral for requested debt
        uint256 requiredCollateralValue = (_abobAmount * collateralRatio) / BASIS_POINTS;
        uint256 currentCollateralValue = getCollateralValue(msg.sender, _collateral);
        uint256 newCollateralValue = getCollateralTokenValue(_collateral, _collateralAmount);

        require(currentCollateralValue + newCollateralValue >= requiredCollateralValue, "Insufficient collateral");

        // Transfer collateral to contract
        IERC20(_collateral).transferFrom(msg.sender, address(this), _collateralAmount);

        // Update vault state
        vault.collateralAmounts[_collateral] += _collateralAmount;
        vault.lastCollateralUpdate[_collateral] = block.timestamp;
        vault.totalDebt += _abobAmount;
        vault.lastInteraction = block.timestamp;

        // Update global state
        supportedCollaterals[_collateral].totalDeposited += _collateralAmount;
        totalSystemDebt += _abobAmount;

        // Mint ABOB to user
        _mint(msg.sender, _abobAmount);

        emit CollateralDeposited(msg.sender, _collateral, _collateralAmount);
        emit AbobMinted(msg.sender, _abobAmount);
    }

    /**
     * @notice Deposit collateral only
     */
    function depositCollateral(
        address _collateral,
        uint256 _amount
    ) external whenNotPaused nonReentrant validCollateral(_collateral) {
        require(_amount > 0, "Invalid amount");

        UserVault storage vault = vaults[msg.sender];

        if (!vault.isActive) {
            vault.isActive = true;
            vault.lastInteraction = block.timestamp;
            vaultUsers.push(msg.sender);
        }

        IERC20(_collateral).transferFrom(msg.sender, address(this), _amount);

        vault.collateralAmounts[_collateral] += _amount;
        vault.lastCollateralUpdate[_collateral] = block.timestamp;
        vault.lastInteraction = block.timestamp;
        supportedCollaterals[_collateral].totalDeposited += _amount;

        emit CollateralDeposited(msg.sender, _collateral, _amount);
    }

    /**
     * @notice Mint ABOB against existing collateral
     */
    function mintAbob(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(totalSystemDebt + _amount <= globalDebtCeiling, "System debt ceiling exceeded");

        UserVault storage vault = vaults[msg.sender];
        require(vault.isActive, "Vault not active");

        // Check if user has sufficient collateral across all types
        uint256 totalCollateralValue = getTotalCollateralValue(msg.sender);
        uint256 newTotalDebt = vault.totalDebt + _amount;
        uint256 requiredCollateralValue = (newTotalDebt * 15000) / BASIS_POINTS; // 150% minimum ratio

        require(totalCollateralValue >= requiredCollateralValue, "Insufficient collateral");

        // Check collateral-specific debt ceilings
        for (uint256 i = 0; i < collateralList.length; i++) {
            address collateral = collateralList[i];
            if (vault.collateralAmounts[collateral] > 0) {
                uint256 collateralDebt = getCollateralDebt(collateral);
                uint256 proportionalDebt = (_amount * vault.collateralAmounts[collateral]) / totalCollateralValue;
                require(collateralDebt + proportionalDebt <= supportedCollaterals[collateral].debtCeiling, "Collateral debt ceiling exceeded");
            }
        }

        vault.totalDebt += _amount;
        vault.lastInteraction = block.timestamp;
        totalSystemDebt += _amount;

        _mint(msg.sender, _amount);

        emit AbobMinted(msg.sender, _amount);
    }

    /**
     * @notice Withdraw collateral and repay debt in one transaction
     */
    function withdrawCollateralAndRepayDebt(
        address _collateral,
        uint256 _collateralAmount,
        uint256 _debtAmount
    ) external whenNotPaused nonReentrant validCollateral(_collateral) {
        require(_collateralAmount > 0 && _debtAmount > 0, "Invalid amounts");

        UserVault storage vault = vaults[msg.sender];
        require(vault.isActive, "Vault not active");
        require(vault.collateralAmounts[_collateral] >= _collateralAmount, "Insufficient collateral");
        require(vault.totalDebt >= _debtAmount, "Insufficient debt");

        // Check if withdrawal would leave vault undercollateralized
        uint256 newCollateralAmount = vault.collateralAmounts[_collateral] - _collateralAmount;
        uint256 newTotalDebt = vault.totalDebt - _debtAmount;

        if (newTotalDebt > 0) {
            uint256 remainingValue = getTotalCollateralValue(msg.sender) - getCollateralTokenValue(_collateral, _collateralAmount);
            uint256 requiredValue = (newTotalDebt * 15000) / BASIS_POINTS;
            require(remainingValue >= requiredValue, "Undercollateralized after withdrawal");
        }

        // Burn ABOB from user
        require(balanceOf(msg.sender) >= _debtAmount, "Insufficient ABOB balance");
        _burn(msg.sender, _debtAmount);

        // Transfer collateral to user
        IERC20(_collateral).transfer(msg.sender, _collateralAmount);

        // Update vault state
        vault.collateralAmounts[_collateral] -= _collateralAmount;
        vault.lastCollateralUpdate[_collateral] = block.timestamp;
        vault.totalDebt = newTotalDebt;
        vault.lastInteraction = block.timestamp;

        // Update global state
        supportedCollaterals[_collateral].totalDeposited -= _collateralAmount;
        totalSystemDebt = newTotalDebt;

        emit CollateralWithdrawn(msg.sender, _collateral, _collateralAmount);
        emit AbobBurned(msg.sender, _debtAmount);
    }

    /**
     * @notice Withdraw collateral only
     */
    function withdrawCollateral(
        address _collateral,
        uint256 _amount
    ) external whenNotPaused nonReentrant validCollateral(_collateral) {
        require(_amount > 0, "Invalid amount");

        UserVault storage vault = vaults[msg.sender];
        require(vault.isActive, "Vault not active");
        require(vault.collateralAmounts[_collateral] >= _amount, "Insufficient collateral");

        // Check if withdrawal would leave vault undercollateralized
        if (vault.totalDebt > 0) {
            uint256 remainingValue = getTotalCollateralValue(msg.sender) - getCollateralTokenValue(_collateral, _amount);
            // Get collateral ratio from CollateralManager
            (bool isSupported, uint256 collateralRatio,,) = ICollateralManager(collateralManager).getCollateralInfo(_collateral);
            require(isSupported, "Collateral not supported");
            uint256 requiredValue = (vault.totalDebt * collateralRatio) / BASIS_POINTS;
            require(remainingValue >= requiredValue, "Undercollateralized after withdrawal");
        }

        IERC20(_collateral).transfer(msg.sender, _amount);

        vault.collateralAmounts[_collateral] -= _amount;
        vault.lastCollateralUpdate[_collateral] = block.timestamp;
        vault.lastInteraction = block.timestamp;
        supportedCollaterals[_collateral].totalDeposited -= _amount;

        emit CollateralWithdrawn(msg.sender, _collateral, _amount);
    }

    /**
     * @notice Repay ABOB debt only
     */
    function repayDebt(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Invalid amount");

        UserVault storage vault = vaults[msg.sender];
        require(vault.isActive, "Vault not active");
        require(vault.totalDebt >= _amount, "Insufficient debt");

        require(balanceOf(msg.sender) >= _amount, "Insufficient ABOB balance");
        _burn(msg.sender, _amount);

        vault.totalDebt -= _amount;
        vault.lastInteraction = block.timestamp;
        totalSystemDebt -= _amount;

        emit AbobBurned(msg.sender, _amount);
    }

    // ==================== LIQUIDATION ====================

    /**
     * @notice Check if a vault is undercollateralized and can be liquidated
     */
    function canLiquidate(address _user) public view returns (bool) {
        UserVault storage vault = vaults[_user];
        if (!vault.isActive || vault.totalDebt == 0) return false;

        uint256 totalCollateralValue = getTotalCollateralValue(_user);
        uint256 minRequiredValue = (vault.totalDebt * 12500) / BASIS_POINTS; // 125% liquidation threshold

        return totalCollateralValue < minRequiredValue;
    }

    /**
     * @notice Liquidate an undercollateralized vault (direct liquidation)
     * @dev This is a fallback mechanism. Primary liquidations should use AuctionManager
     */
    function liquidateVault(address _user) external whenNotPaused nonReentrant {
        require(canLiquidate(_user), "Vault cannot be liquidated");

        UserVault storage vault = vaults[_user];
        require(vault.isActive, "Vault not active");

        uint256 totalDebt = vault.totalDebt;
        uint256 totalCollateralValue = getTotalCollateralValue(_user);

        // Calculate liquidation bonus (5%)
        uint256 liquidationBonus = (totalDebt * LIQUIDATION_PENALTY) / BASIS_POINTS;
        uint256 debtToRepay = totalDebt + liquidationBonus;

        require(balanceOf(msg.sender) >= debtToRepay, "Insufficient ABOB for liquidation");
        require(totalCollateralValue >= debtToRepay, "Insufficient collateral value");

        // Burn liquidator's ABOB
        _burn(msg.sender, debtToRepay);

        // Transfer all collateral to liquidator
        for (uint256 i = 0; i < collateralList.length; i++) {
            address collateral = collateralList[i];
            uint256 amount = vault.collateralAmounts[collateral];
            if (amount > 0) {
                IERC20(collateral).transfer(msg.sender, amount);
                supportedCollaterals[collateral].totalDeposited -= amount;
            }
        }

        // Clear vault
        vault.totalDebt = 0;
        vault.lastInteraction = block.timestamp;
        totalSystemDebt -= totalDebt;

        emit LiquidationTriggered(_user, msg.sender, debtToRepay, totalCollateralValue);
    }

    /**
     * @notice Start auction liquidation for an undercollateralized vault
     * @dev Preferred liquidation method using AuctionManager
     */
    function startAuctionLiquidation(address _user) external onlyLiquidationManager whenNotPaused {
        require(canLiquidate(_user), "Vault cannot be liquidated");

        UserVault storage vault = vaults[_user];
        require(vault.isActive, "Vault not active");

        // Find the primary collateral (largest amount)
        address primaryCollateral;
        uint256 maxAmount = 0;

        for (uint256 i = 0; i < collateralList.length; i++) {
            address collateral = collateralList[i];
            uint256 amount = vault.collateralAmounts[collateral];
            if (amount > maxAmount) {
                maxAmount = amount;
                primaryCollateral = collateral;
            }
        }

        require(primaryCollateral != address(0), "No collateral found");
        require(liquidationManager != address(0), "No liquidation manager set");

        // Transfer collateral to AuctionManager
        IERC20(primaryCollateral).transfer(liquidationManager, maxAmount);

        // Update vault state
        vault.collateralAmounts[primaryCollateral] = 0;
        supportedCollaterals[primaryCollateral].totalDeposited -= maxAmount;

        // Start auction through AuctionManager
        try IAuctionManager(liquidationManager).startLiquidationAuction(
            _user,
            primaryCollateral,
            maxAmount,
            vault.totalDebt
        ) returns (uint256 auctionId) {
            emit AuctionCreated(auctionId, _user, primaryCollateral, maxAmount, 0);
        } catch Error(string memory reason) {
            // Revert collateral if auction fails
            IERC20(primaryCollateral).transferFrom(liquidationManager, address(this), maxAmount);
            vault.collateralAmounts[primaryCollateral] = maxAmount;
            supportedCollaterals[primaryCollateral].totalDeposited += maxAmount;
            revert(string(abi.encodePacked("Auction failed: ", reason)));
        }
    }

    // ==================== REDEMPTION ====================

    /**
     * @notice Redeem ABOB for proportional collateral
     */
    function redeemAbob(uint256 _abobAmount) external whenNotPaused nonReentrant {
        require(_abobAmount >= minRedemptionAmount, "Below minimum redemption");
        require(balanceOf(msg.sender) >= _abobAmount, "Insufficient ABOB balance");
        require(totalSystemDebt >= _abobAmount, "Exceeds system debt");

        // Check redemption cooldown
        require(block.timestamp >= lastStabilityFeeCollection + redemptionCooldown, "Redemption cooldown active");

        uint256 feeAmount = (_abobAmount * redemptionFee) / BASIS_POINTS;
        uint256 redeemAmount = _abobAmount - feeAmount;

        // Burn ABOB
        _burn(msg.sender, _abobAmount);

        // Calculate proportional collateral claims
        address[] memory collateralTokens = new address[](collateralList.length);
        uint256[] memory collateralAmounts = new uint256[](collateralList.length);

        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < collateralList.length; i++) {
            address collateral = collateralList[i];
            uint256 value = getCollateralTokenValue(collateral, supportedCollaterals[collateral].totalDeposited);
            totalCollateralValue += value;
        }

        for (uint256 i = 0; i < collateralList.length; i++) {
            address collateral = collateralList[i];
            uint256 deposited = supportedCollaterals[collateral].totalDeposited;
            if (deposited > 0 && totalCollateralValue > 0) {
                uint256 collateralValue = getCollateralTokenValue(collateral, deposited);
                uint256 proportionalValue = (collateralValue * redeemAmount) / totalSystemDebt;
                collateralAmounts[i] = (proportionalValue * 1e18) / getCollateralPrice(collateral);
                collateralTokens[i] = collateral;

                if (collateralAmounts[i] > 0) {
                    IERC20(collateral).transfer(msg.sender, collateralAmounts[i]);
                    supportedCollaterals[collateral].totalDeposited -= collateralAmounts[i];
                }
            }
        }

        totalSystemDebt -= _abobAmount;

        emit Redemption(msg.sender, _abobAmount, collateralTokens, collateralAmounts);
    }

    // ==================== GOVERNANCE ====================

    /**
     * @notice Initiate governance transfer
     */
    function transferGovernance(address _newGovernance) external onlyGovernance {
        require(_newGovernance != address(0), "Invalid address");
        pendingGovernance = _newGovernance;
        governanceTransferInitiated = block.timestamp;

        emit GovernanceTransferInitiated(governance, _newGovernance);
    }

    /**
     * @notice Accept governance transfer
     */
    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "Not pending governance");
        require(block.timestamp >= governanceTransferInitiated + governanceTransferDelay, "Delay not met");

        address oldGovernance = governance;
        governance = pendingGovernance;
        pendingGovernance = address(0);

        _revokeRole(GOVERNANCE_ROLE, oldGovernance);
        _grantRole(GOVERNANCE_ROLE, governance);

        emit GovernanceTransferred(oldGovernance, governance);
    }

    /**
     * @notice Update system parameters
     */
    function updateSystemParameters(
        uint256 _globalDebtCeiling,
        uint256 _redemptionFee,
        uint256 _minRedemptionAmount,
        uint256 _redemptionCooldown,
        uint256 _stabilityFeeRate
    ) external onlyGovernance {
        globalDebtCeiling = _globalDebtCeiling;
        redemptionFee = _redemptionFee;
        minRedemptionAmount = _minRedemptionAmount;
        redemptionCooldown = _redemptionCooldown;
        stabilityFeeRate = _stabilityFeeRate;
    }

    // ==================== EMERGENCY ====================

    /**
     * @notice Toggle emergency mode
     */
    function toggleEmergencyMode(bool _enabled) external onlyPauser {
        emergencyMode = _enabled;
        emit EmergencyModeToggled(_enabled);
    }

    /**
     * @notice Emergency mint ABOB (limited capacity)
     */
    function emergencyMint(uint256 _amount) external onlyGovernance {
        require(emergencyMode, "Emergency mode not active");
        require(emergencyMinted + _amount <= emergencyMintingCap, "Emergency cap exceeded");

        emergencyMinted += _amount;
        _mint(governance, _amount);
    }

    // ==================== MIGRATION ====================

    /**
     * @notice Enable migration to new contract
     */
    function enableMigration(address _target) external onlyGovernance {
        migrationEnabled = true;
        migrationTarget = _target;
    }

    /**
     * @notice Migrate position to new contract
     */
    function migratePosition() external nonReentrant {
        require(migrationEnabled, "Migration not enabled");
        require(!hasMigrated[msg.sender], "Already migrated");

        UserVault storage vault = vaults[msg.sender];
        require(vault.isActive, "No active position");

        hasMigrated[msg.sender] = true;

        // Implementation would interact with migration target contract
        // This is a placeholder for the actual migration logic

        emit Migration(msg.sender, migrationTarget, vault.totalDebt);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Get user vault information
     */
    function getUserVaultInfo(address _user)
        external
        view
        returns (
            uint256 totalCollateralValue,
            uint256 totalDebt,
            uint256 healthFactor
        )
    {
        UserVault storage vault = vaults[_user];
        if (!vault.isActive) {
            return (0, 0, 0);
        }

        totalCollateralValue = getTotalCollateralValue(_user);
        totalDebt = vault.totalDebt;

        if (totalDebt > 0) {
            healthFactor = (totalCollateralValue * BASIS_POINTS) / totalDebt;
        } else {
            healthFactor = 0; // 0 ratio when no debt
        }
    }

    /**
     * @notice Get system information
     */
    function getSystemInfo()
        external
        view
        returns (
            uint256 totalCollateral,
            uint256 totalDebt,
            uint256 systemRatio
        )
    {
        totalDebt = totalSystemDebt;

        // Get supported collaterals list
        address[] memory collaterals;
        if (collateralManager != address(0)) {
            try ICollateralManager(collateralManager).getSupportedCollaterals() returns (address[] memory _collaterals) {
                collaterals = _collaterals;
            } catch {
                collaterals = collateralList; // Fallback to local list
            }
        } else {
            collaterals = collateralList;
        }

        for (uint256 i = 0; i < collaterals.length; i++) {
            address collateral = collaterals[i];
            uint256 amount = supportedCollaterals[collateral].totalDeposited;
            if (amount > 0) {
                totalCollateral += getCollateralTokenValue(collateral, amount);
            }
        }

        if (totalDebt > 0) {
            systemRatio = (totalCollateral * BASIS_POINTS) / totalDebt;
        } else {
            systemRatio = 0; // 0 ratio when no debt
        }
    }

    /**
     * @notice Get collateral information
     */
    function getCollateralInfo(address _collateral)
        external
        view
        returns (
            bool isSupported,
            uint256 ratio,
            uint256 threshold,
            uint256 ceiling,
            uint256 totalDeposited
        )
    {
        CollateralInfo storage info = supportedCollaterals[_collateral];
        return (
            info.isSupported,
            info.collateralRatio,
            info.liquidationThreshold,
            info.debtCeiling,
            info.totalDeposited
        );
    }

    /**
     * @notice Get total collateral value for a user
     */
    function getTotalCollateralValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;

        // Get supported collaterals list
        address[] memory collaterals;
        if (collateralManager != address(0)) {
            try ICollateralManager(collateralManager).getSupportedCollaterals() returns (address[] memory _collaterals) {
                collaterals = _collaterals;
            } catch {
                collaterals = collateralList; // Fallback to local list
            }
        } else {
            collaterals = collateralList;
        }

        for (uint256 i = 0; i < collaterals.length; i++) {
            address collateral = collaterals[i];
            uint256 amount = vaults[_user].collateralAmounts[collateral];
            if (amount > 0) {
                totalValue += getCollateralTokenValue(collateral, amount);
            }
        }

        return totalValue;
    }

    /**
     * @notice Get collateral value for specific token
     */
    function getCollateralValue(address _user, address _collateral) public view returns (uint256) {
        uint256 amount = vaults[_user].collateralAmounts[_collateral];
        return getCollateralTokenValue(_collateral, amount);
    }

    /**
     * @notice Get value of collateral tokens
     */
    function getCollateralTokenValue(address _collateral, uint256 _amount) public view returns (uint256) {
        if (_amount == 0) return 0;

        uint256 price = getCollateralPrice(_collateral);

        // Normalize amount to 18 decimals before calculating value
        uint256 decimals = IERC20Metadata(_collateral).decimals();
        uint256 normalizedAmount;
        if (decimals < 18) {
            normalizedAmount = _amount * 10**(18 - decimals);
        } else if (decimals > 18) {
            normalizedAmount = _amount / 10**(decimals - 18);
        } else {
            normalizedAmount = _amount;
        }

        // price is already normalized to 18 decimals
        return (normalizedAmount * price) / 1e18;
    }

    /**
     * @notice Get collateral price from oracle
     */
    function getCollateralPrice(address _collateral) public view returns (uint256) {
        if (priceOracle == address(0)) return 1e18; // Fallback to 1 USD

        // Get price oracle from collateral manager if available
        address collateralOracle = priceOracle;
        if (collateralManager != address(0)) {
            try ICollateralManager(collateralManager).getPriceOracle(_collateral) returns (address oracle) {
                if (oracle != address(0)) {
                    collateralOracle = oracle;
                }
            } catch {
                // Use default oracle if call fails
            }
        }

        // Get price from oracle
        try IPriceOracle(collateralOracle).getMedianPrice(_collateral) returns (uint256 price) {
            return price;
        } catch {
            // Fallback to 1 USD if oracle call fails
            return 1e18;
        }
    }

    /**
     * @notice Get total debt issued against specific collateral
     */
    function getCollateralDebt(address _collateral) public view returns (uint256) {
        uint256 totalDebt = 0;

        for (uint256 i = 0; i < vaultUsers.length; i++) {
            address user = vaultUsers[i];
            if (vaults[user].collateralAmounts[_collateral] > 0) {
                totalDebt += vaults[user].totalDebt;
            }
        }

        return totalDebt;
    }

    // ==================== ADMIN FUNCTIONS ====================

    /**
     * @notice Pause contract
     */
    function pause() external onlyPauser {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyPauser {
        _unpause();
    }

    /**
     * @notice Add supported collateral (for backward compatibility)
     */
    function addSupportedCollateral(address _collateral) external onlyGovernance {
        require(_collateral != address(0), "Invalid address");
        if (!supportedCollaterals[_collateral].isSupported) {
            // Add with default parameters directly
            if (collateralManager != address(0)) {
                ICollateralManager(collateralManager).addCollateral(
                    _collateral,
                    15000,           // 150% ratio
                    12500,           // 125% threshold
                    10_000_000 * 1e18, // 10M ABOB ceiling
                    100 * 1e18,      // 100 ABOB min
                    priceOracle
                );
            } else {
                // Fallback for when no CollateralManager
                supportedCollaterals[_collateral] = CollateralInfo({
                    isSupported: true,
                    collateralRatio: 15000,
                    liquidationThreshold: 12500,
                    debtCeiling: 10_000_000 * 1e18,
                    minDeposit: 100 * 1e18,
                    totalDeposited: 0,
                    priceOracle: priceOracle
                });
                collateralList.push(_collateral);
                emit CollateralAdded(_collateral, 15000, 12500, 10_000_000 * 1e18);
            }
        }
    }

    // ==================== UPGRADE ====================

    
    // ==================== FALLBACK ====================

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Invalid function call");
    }
}