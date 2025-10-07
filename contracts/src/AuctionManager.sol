// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IAbobToken {
    function liquidateVault(address user, uint256 debtToRepay) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ICollateralManager {
    function getCollateralInfo(address token) external view returns (
        bool isSupported,
        uint256 overCollateralizationRatio,
        uint256 liquidationThreshold,
        uint256 debtCeiling
    );
}

/**
 * @title AuctionManager
 * @author Ande Labs
 * @notice Gestiona subastas holandesas para liquidación de vaults con colateral insuficiente
 * @dev Implementa subastas donde el precio del colateral disminuye con el tiempo
 */
contract AuctionManager is Initializable, OwnableUpgradeable, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // ==================== STRUCTS ====================
    struct Auction {
        address vaultOwner;
        address collateralToken;
        uint256 totalDebt;
        uint256 collateralAmount;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 duration;
        uint256 currentPrice;
        bool isActive;
        address highestBidder;
        uint256 highestBidAmount;
    }

    struct AuctionParameters {
        uint256 baseDuration;         // Base duration in seconds (e.g., 6 hours)
        uint256 priceDecayRate;       // Price decay rate (basis points per hour)
        uint256 minBidIncrement;      // Minimum bid increment (basis points)
        uint256 liquidationPenalty;   // Liquidation penalty (basis points)
        uint256 maxAuctionDuration;   // Maximum auction duration
    }

    // ==================== CONSTANTS ====================
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant DEFAULT_DURATION = 6 hours;
    uint256 private constant DEFAULT_PRICE_DECAY = 1000; // 10% per hour
    uint256 private constant DEFAULT_MIN_BID_INCREMENT = 100; // 1%
    uint256 private constant DEFAULT_LIQUIDATION_PENALTY = 1000; // 10%
    uint256 private constant DEFAULT_MAX_DURATION = 24 hours;

    // ==================== STORAGE ====================
    IAbobToken public abobToken;
    ICollateralManager public collateralManager;

    mapping(uint256 => Auction) public auctions;
    uint256 public nextAuctionId;

    AuctionParameters public auctionParams;

    // Track auction statistics
    uint256 public totalAuctions;
    uint256 public successfulAuctions;
    uint256 public totalCollateralLiquidated;
    uint256 public totalDebtRecovered;

    // ==================== EVENTS ====================
    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed vaultOwner,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 totalDebt,
        uint256 startPrice
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount,
        uint256 collateralReceived
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice,
        uint256 debtRepaid,
        uint256 collateralTransferred
    );
    event AuctionCancelled(uint256 indexed auctionId, string reason);
    event AuctionParametersUpdated(
        uint256 baseDuration,
        uint256 priceDecayRate,
        uint256 minBidIncrement,
        uint256 liquidationPenalty
    );

    // ==================== ERRORS ====================
    error AuctionNotFound();
    error AuctionNotActive();
    error AuctionExpired();
    error InsufficientBid();
    error InvalidAuctionParameters();
    error UnauthorizedLiquidation();
    error NothingToLiquidate();
    error BidTooLow();
    error CannotBidOnOwnAuction();
    error CollateralTransferFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address _abobToken,
        address _collateralManager
    ) public initializer {
        __Ownable_init(defaultAdmin);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        abobToken = IAbobToken(_abobToken);
        collateralManager = ICollateralManager(_collateralManager);

        auctionParams = AuctionParameters({
            baseDuration: DEFAULT_DURATION,
            priceDecayRate: DEFAULT_PRICE_DECAY,
            minBidIncrement: DEFAULT_MIN_BID_INCREMENT,
            liquidationPenalty: DEFAULT_LIQUIDATION_PENALTY,
            maxAuctionDuration: DEFAULT_MAX_DURATION
        });
    }

    // ==================== LIQUIDATION FUNCTIONS ====================

    /**
     * @notice Start a liquidation auction for an undercollateralized vault
     * @param vaultOwner Address of the vault owner
     * @param collateralToken Address of the collateral to liquidate
     * @param collateralAmount Amount of collateral to auction
     * @param totalDebt Total debt to be repaid
     */
    function startLiquidationAuction(
        address vaultOwner,
        address collateralToken,
        uint256 collateralAmount,
        uint256 totalDebt
    ) external whenNotPaused nonReentrant returns (uint256 auctionId) {
        if (collateralAmount == 0 || totalDebt == 0) revert NothingToLiquidate();

        // Validate collateral is supported
        (bool isSupported,,,) = collateralManager.getCollateralInfo(collateralToken);
        if (!isSupported) revert InvalidAuctionParameters();

        auctionId = nextAuctionId++;
        uint256 startPrice = _calculateStartPrice(collateralToken, totalDebt, collateralAmount);
        uint256 endPrice = _calculateEndPrice(startPrice);

        auctions[auctionId] = Auction({
            vaultOwner: vaultOwner,
            collateralToken: collateralToken,
            totalDebt: totalDebt,
            collateralAmount: collateralAmount,
            startPrice: startPrice,
            endPrice: endPrice,
            startTime: block.timestamp,
            duration: auctionParams.baseDuration,
            currentPrice: startPrice,
            isActive: true,
            highestBidder: address(0),
            highestBidAmount: 0
        });

        totalAuctions++;
        totalCollateralLiquidated += collateralAmount;

        emit AuctionStarted(auctionId, vaultOwner, collateralToken, collateralAmount, totalDebt, startPrice);
    }

    /**
     * @notice Place a bid in an active auction
     * @param auctionId The auction ID
     * @param bidAmount Amount of ABOB to bid
     */
    function placeBid(uint256 auctionId, uint256 bidAmount) external whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (!auction.isActive) revert AuctionNotActive();
        if (block.timestamp > auction.startTime + auction.duration) revert AuctionExpired();
        if (msg.sender == auction.vaultOwner) revert CannotBidOnOwnAuction();

        // Update current price (Dutch auction decay)
        auction.currentPrice = _getCurrentPrice(auction);

        // Calculate minimum bid
        uint256 minBid = Math.mulDiv(auction.collateralAmount, auction.currentPrice, 1e18);
        uint256 requiredBid = Math.mulDiv(minBid, BASIS_POINTS + auctionParams.minBidIncrement, BASIS_POINTS);

        if (bidAmount < requiredBid) revert BidTooLow();

        // Check if this is a winning bid
        if (bidAmount > auction.highestBidAmount) {
            // Refund previous highest bidder if exists
            if (auction.highestBidder != address(0)) {
                abobToken.transfer(auction.highestBidder, auction.highestBidAmount);
            }

            // Transfer new bid
            abobToken.transferFrom(msg.sender, address(this), bidAmount);

            auction.highestBidder = msg.sender;
            auction.highestBidAmount = bidAmount;

            emit BidPlaced(auctionId, msg.sender, bidAmount, auction.collateralAmount);
        }
    }

    /**
     * @notice End an auction and transfer collateral to winner
     * @param auctionId The auction ID
     */
    function endAuction(uint256 auctionId) external whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (!auction.isActive) revert AuctionNotActive();

        // Check if auction has expired or has a winning bid
        bool auctionExpired = block.timestamp > auction.startTime + auction.duration;
        bool hasWinner = auction.highestBidder != address(0);

        if (!auctionExpired && !hasWinner) {
            revert AuctionNotActive();
        }

        if (hasWinner) {
            // Successful auction
            _processSuccessfulAuction(auctionId);
            successfulAuctions++;
            totalDebtRecovered += Math.min(auction.highestBidAmount, auction.totalDebt);
        } else {
            // Failed auction - liquidate through AbobToken
            _processFailedAuction(auctionId);
        }

        auction.isActive = false;
    }

    // ==================== INTERNAL FUNCTIONS ====================

    function _processSuccessfulAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];

        // Calculate debt repayment and penalty
        uint256 debtRepaid = Math.min(auction.highestBidAmount, auction.totalDebt);
        uint256 penaltyAmount = Math.mulDiv(debtRepaid, auctionParams.liquidationPenalty, BASIS_POINTS);
        uint256 totalToBurn = debtRepaid + penaltyAmount;

        // Burn ABOB to repay debt
        require(
            abobToken.transferFrom(address(this), address(this), totalToBurn),
            "ABOB transfer failed"
        );

        // Transfer collateral to winner
        IERC20 collateralToken = IERC20(auction.collateralToken);
        collateralToken.safeTransfer(auction.highestBidder, auction.collateralAmount);

        // Refund excess bid to winner
        if (auction.highestBidAmount > debtRepaid + penaltyAmount) {
            uint256 refund = auction.highestBidAmount - debtRepaid - penaltyAmount;
            abobToken.transfer(auction.highestBidder, refund);
        }

        emit AuctionEnded(
            auctionId,
            auction.highestBidder,
            auction.currentPrice,
            debtRepaid,
            auction.collateralAmount
        );
    }

    function _processFailedAuction(uint256 auctionId) internal {
        Auction storage auction = auctions[auctionId];

        // Try to liquidate through AbobToken contract
        try abobToken.liquidateVault(auction.vaultOwner, auction.totalDebt) {
            // Liquidation successful through AbobToken
        } catch {
            // Mark auction as failed but inactive
            emit AuctionCancelled(auctionId, "Liquidation failed");
        }
    }

    function _calculateStartPrice(
        address collateralToken,
        uint256 totalDebt,
        uint256 collateralAmount
    ) internal view returns (uint256 startPrice) {
        // Start with a premium to encourage early bidding
        uint256 basePrice = Math.mulDiv(totalDebt, 1e18, collateralAmount);
        uint256 premium = Math.mulDiv(basePrice, auctionParams.liquidationPenalty, BASIS_POINTS);
        return basePrice + premium;
    }

    function _calculateEndPrice(uint256 startPrice) internal view returns (uint256 endPrice) {
        // End price is significantly lower to ensure liquidation
        uint256 maxDecay = Math.mulDiv(startPrice, auctionParams.priceDecayRate * 4, BASIS_POINTS); // 4 hours of decay
        return startPrice > maxDecay ? startPrice - maxDecay : startPrice / 10; // Minimum 10% of start price
    }

    function _getCurrentPrice(Auction storage auction) internal view returns (uint256 currentPrice) {
        uint256 timeElapsed = block.timestamp - auction.startTime;
        uint256 decayRate = Math.mulDiv(auctionParams.priceDecayRate, timeElapsed, 1 hours);

        uint256 totalDecay = decayRate > (BASIS_POINTS * 80 / 100) ? (BASIS_POINTS * 80 / 100) : decayRate; // Max 80% decay
        uint256 priceReduction = Math.mulDiv(auction.startPrice, totalDecay, BASIS_POINTS);

        currentPrice = auction.startPrice - priceReduction;
        return currentPrice > auction.endPrice ? currentPrice : auction.endPrice;
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Get auction information
     * @param auctionId The auction ID
     * @return auction Complete auction struct
     */
    function getAuction(uint256 auctionId) external view returns (Auction memory auction) {
        return auctions[auctionId];
    }

    /**
     * @notice Get current price for an auction
     * @param auctionId The auction ID
     * @return currentPrice Current price in ABOB per collateral unit (18 decimals)
     */
    function getCurrentPrice(uint256 auctionId) external view returns (uint256 currentPrice) {
        Auction storage auction = auctions[auctionId];
        if (!auction.isActive) revert AuctionNotActive();
        return _getCurrentPrice(auction);
    }

    /**
     * @notice Get minimum bid required for an auction
     * @param auctionId The auction ID
     * @return minBid Minimum bid amount
     */
    function getMinimumBid(uint256 auctionId) external view returns (uint256 minBid) {
        Auction storage auction = auctions[auctionId];
        if (!auction.isActive) revert AuctionNotActive();

        uint256 currentPrice = _getCurrentPrice(auction);
        uint256 baseBid = Math.mulDiv(auction.collateralAmount, currentPrice, 1e18);
        return Math.mulDiv(baseBid, BASIS_POINTS + auctionParams.minBidIncrement, BASIS_POINTS);
    }

    /**
     * @notice Get auction statistics
     * @return _totalAuctions Total auctions created
     * @return _successfulAuctions Successful auctions
     * @return _totalCollateralLiquidated Total collateral liquidated
     * @return _totalDebtRecovered Total debt recovered
     * @return successRate Success rate in basis points
     */
    function getAuctionStats() external view returns (
        uint256 _totalAuctions,
        uint256 _successfulAuctions,
        uint256 _totalCollateralLiquidated,
        uint256 _totalDebtRecovered,
        uint256 successRate
    ) {
        _totalAuctions = totalAuctions;
        _successfulAuctions = successfulAuctions;
        _totalCollateralLiquidated = totalCollateralLiquidated;
        _totalDebtRecovered = totalDebtRecovered;
        successRate = totalAuctions > 0
            ? Math.mulDiv(successfulAuctions, BASIS_POINTS, totalAuctions)
            : 0;
    }

    /**
     * @notice Check if an auction can be started
     * @param vaultOwner The vault owner address
     * @param collateralToken The collateral token address
     * @return canStart Whether auction can be started
     * @return reason Reason if cannot start
     */
    function canStartAuction(address vaultOwner, address collateralToken)
        external
        view
        returns (bool canStart, string memory reason)
    {
        (bool isSupported,,,) = collateralManager.getCollateralInfo(collateralToken);
        if (!isSupported) {
            return (false, "Collateral not supported");
        }

        if (paused()) {
            return (false, "Contract paused");
        }

        return (true, "");
    }

    // ==================== ADMIN FUNCTIONS ====================

    /**
     * @notice Update auction parameters
     * @param baseDuration Base auction duration
     * @param priceDecayRate Price decay rate per hour
     * @param minBidIncrement Minimum bid increment
     * @param liquidationPenalty Liquidation penalty
     */
    function updateAuctionParameters(
        uint256 baseDuration,
        uint256 priceDecayRate,
        uint256 minBidIncrement,
        uint256 liquidationPenalty
    ) external onlyOwner {
        if (baseDuration == 0 || baseDuration > auctionParams.maxAuctionDuration) {
            revert InvalidAuctionParameters();
        }
        if (priceDecayRate > BASIS_POINTS) revert InvalidAuctionParameters();
        if (minBidIncrement > BASIS_POINTS / 2) revert InvalidAuctionParameters(); // Max 50%
        if (liquidationPenalty > BASIS_POINTS) revert InvalidAuctionParameters();

        auctionParams.baseDuration = baseDuration;
        auctionParams.priceDecayRate = priceDecayRate;
        auctionParams.minBidIncrement = minBidIncrement;
        auctionParams.liquidationPenalty = liquidationPenalty;

        emit AuctionParametersUpdated(baseDuration, priceDecayRate, minBidIncrement, liquidationPenalty);
    }

    /**
     * @notice Cancel an active auction (emergency only)
     * @param auctionId The auction ID
     * @param reason Reason for cancellation
     */
    function emergencyCancelAuction(uint256 auctionId, string calldata reason) external onlyOwner {
        Auction storage auction = auctions[auctionId];
        if (!auction.isActive) revert AuctionNotActive();

        // Refund highest bidder if exists
        if (auction.highestBidder != address(0)) {
            abobToken.transfer(auction.highestBidder, auction.highestBidAmount);
        }

        auction.isActive = false;
        emit AuctionCancelled(auctionId, reason);
    }

    // ==================== UPGRADE ====================

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}