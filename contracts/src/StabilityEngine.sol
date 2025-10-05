// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IOracle.sol";
import "./ANDEToken.sol";
import "./AusdToken.sol";

/// @title StabilityEngine
/// @author AndeLabs
/// @notice Este contrato gestiona la acuñación y quema de la stablecoin aUSD,
/// utilizando ANDE como colateral y manteniendo la estabilidad del sistema.
contract StabilityEngine is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    ANDEToken public andeToken;
    AusdToken public ausdToken;
    IOracle public andeUsdOracle;

    uint256 public collateralRatio; // e.g., 150 for 150%

    // --- Events ---

    event Minted(address indexed user, uint256 andeAmount, uint256 ausdAmount);
    event Burned(address indexed user, uint256 ausdAmount, uint256 andeAmount);

    // --- Errors ---
    error AmountMustBePositive();
    error OraclePriceInvalid();
    error InsufficientCollateral();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Inicializa el contrato, estableciendo las dependencias clave.
    /// @param initialOwner El propietario inicial del contrato.
    /// @param _andeToken La dirección del token ANDE.
    /// @param _ausdToken La dirección del token aUSD.
    /// @param _andeUsdOracle La dirección del oráculo de precios ANDE/USD.
    /// @param _collateralRatio El ratio de colateralización inicial (e.g., 150 para 150%).
    function initialize(
        address initialOwner,
        address _andeToken,
        address _ausdToken,
        address _andeUsdOracle,
        uint256 _collateralRatio
    ) public initializer {
        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();

        andeToken = ANDEToken(_andeToken);
        ausdToken = AusdToken(_ausdToken);
        andeUsdOracle = IOracle(_andeUsdOracle);
        collateralRatio = _collateralRatio;
    }

    // --- Core Functions ---

    /// @notice Acuña una cantidad de aUSD depositando ANDE como colateral.
    /// @param amountToMint La cantidad de aUSD a acuñar.
    function mint(uint256 amountToMint) external whenNotPaused nonReentrant {
        if (amountToMint == 0) revert AmountMustBePositive();

        (, int256 price_signed, , , ) = andeUsdOracle.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 andePrice = uint256(price_signed);
        uint8 oracleDecimals = andeUsdOracle.decimals();

        // Calculate required ANDE collateral
        // (amountToMint * collateralRatio / 100) * 1e18 / andePrice
        uint256 requiredAndeValue = (amountToMint * collateralRatio) / 100;
        uint256 requiredAndeAmount = (requiredAndeValue * (10**oracleDecimals)) / andePrice;

        // Transfer ANDE from user to this contract
        IERC20(address(andeToken)).safeTransferFrom(msg.sender, address(this), requiredAndeAmount);

        // Mint aUSD to the user
        ausdToken.mint(msg.sender, amountToMint);

        emit Minted(msg.sender, requiredAndeAmount, amountToMint);
    }

    /// @notice Quema aUSD para redimir el colateral de ANDE.
    /// @param amountToBurn La cantidad de aUSD a quemar.
    function burn(uint256 amountToBurn) external whenNotPaused nonReentrant {
        if (amountToBurn == 0) revert AmountMustBePositive();

        // Burn aUSD from the user (user must have approved this contract)
        ausdToken.burnFrom(msg.sender, amountToBurn);

        (, int256 price_signed, , , ) = andeUsdOracle.latestRoundData();
        if (price_signed <= 0) revert OraclePriceInvalid();
        uint256 andePrice = uint256(price_signed);
        uint8 oracleDecimals = andeUsdOracle.decimals();

        // Calculate ANDE to return
        uint256 andeValueToReturn = (amountToBurn * 100) / collateralRatio;
        uint256 andeAmountToReturn = (andeValueToReturn * (10**oracleDecimals)) / andePrice;

        uint256 contractBalance = IERC20(address(andeToken)).balanceOf(address(this));
        if (andeAmountToReturn > contractBalance) revert InsufficientCollateral();

        // Transfer ANDE from this contract to the user
        IERC20(address(andeToken)).safeTransfer(msg.sender, andeAmountToReturn);

        emit Burned(msg.sender, amountToBurn, andeAmountToReturn);
    }

    // --- Admin Functions ---

    function setCollateralRatio(uint256 _newRatio) external onlyOwner {
        collateralRatio = _newRatio;
    }

    // --- Pausable Functions ---

    /// @notice Pausa el contrato en caso de emergencia. Solo el propietario.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Reanuda el contrato. Solo el propietario.
    function unpause() external onlyOwner {
        _unpause();
    }
}
