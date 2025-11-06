// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";

/**
 * @title XERC20
 * @author Ande Labs (adapted from ERC-7281 standard)
 * @notice Base implementation of xERC20 - sovereign cross-chain token standard
 * @dev Implements rate-limited bridge minting/burning with granular permission control
 *
 * Key Features:
 * - Bridge whitelisting with individual rate limits
 * - Automatic limit replenishment over time
 * - Lockbox support for wrapping existing ERC20 tokens
 * - Upgradeable via UUPS pattern
 * - EIP-2612 Permit support for gasless approvals
 */
contract XERC20 is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IXERC20
{
    // ==================== CONSTANTS ====================

    /// @notice Duration for limit replenishment (1 day)
    uint256 private constant _DURATION = 1 days;

    /// @notice Role for managing bridge limits
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");

    // ==================== STATE VARIABLES ====================

    /// @notice Address of the lockbox contract (if any)
    address public lockbox;

    /// @notice Mapping of bridge addresses to their minting/burning parameters
    mapping(address => Bridge) public bridges;

    // ==================== CONSTRUCTOR ====================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ==================== INITIALIZATION ====================

    /**
     * @notice Initializes the xERC20 token
     * @param name Token name
     * @param symbol Token symbol
     * @param admin Address that will have admin and bridge manager roles
     */
    function initialize(string memory name, string memory symbol, address admin) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BRIDGE_MANAGER_ROLE, admin);
    }

    // ==================== BRIDGE MANAGEMENT ====================

    /**
     * @inheritdoc IXERC20
     */
    function setLockbox(address _lockbox) external onlyRole(DEFAULT_ADMIN_ROLE) {
        lockbox = _lockbox;
        emit LockboxSet(_lockbox);
    }

    /**
     * @inheritdoc IXERC20
     */
    function setLimits(address _bridge, uint256 _mintingLimit, uint256 _burningLimit)
        external
        onlyRole(BRIDGE_MANAGER_ROLE)
    {
        _changeMinterLimit(_bridge, _mintingLimit);
        _changeBurnerLimit(_bridge, _burningLimit);
        emit BridgeLimitsSet(_mintingLimit, _burningLimit, _bridge);
    }

    // ==================== MINTING & BURNING ====================

    /**
     * @inheritdoc IXERC20
     */
    function mint(address _user, uint256 _amount) external {
        _mintWithCaller(msg.sender, _user, _amount);
    }

    /**
     * @inheritdoc IXERC20
     */
    function burn(address _user, uint256 _amount) external {
        if (msg.sender != _user) {
            _spendAllowance(_user, msg.sender, _amount);
        }

        _burnWithCaller(msg.sender, _user, _amount);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @inheritdoc IXERC20
     */
    function mintingMaxLimitOf(address _minter) external view returns (uint256) {
        return bridges[_minter].minterParams.maxLimit;
    }

    /**
     * @inheritdoc IXERC20
     */
    function burningMaxLimitOf(address _burner) external view returns (uint256) {
        return bridges[_burner].burnerParams.maxLimit;
    }

    /**
     * @inheritdoc IXERC20
     */
    function mintingCurrentLimitOf(address _minter) external view returns (uint256) {
        return _getCurrentLimit(
            bridges[_minter].minterParams.currentLimit,
            bridges[_minter].minterParams.maxLimit,
            bridges[_minter].minterParams.timestamp,
            bridges[_minter].minterParams.ratePerSecond
        );
    }

    /**
     * @inheritdoc IXERC20
     */
    function burningCurrentLimitOf(address _burner) external view returns (uint256) {
        return _getCurrentLimit(
            bridges[_burner].burnerParams.currentLimit,
            bridges[_burner].burnerParams.maxLimit,
            bridges[_burner].burnerParams.timestamp,
            bridges[_burner].burnerParams.ratePerSecond
        );
    }

    // ==================== INTERNAL FUNCTIONS ====================

    /**
     * @notice Internal mint with caller validation and limit checking
     * @param _caller Address calling the mint function
     * @param _user Address to mint tokens to
     * @param _amount Amount to mint
     */
    function _mintWithCaller(address _caller, address _user, uint256 _amount) internal {
        if (_caller != lockbox) {
            uint256 currentLimit = _getCurrentLimit(
                bridges[_caller].minterParams.currentLimit,
                bridges[_caller].minterParams.maxLimit,
                bridges[_caller].minterParams.timestamp,
                bridges[_caller].minterParams.ratePerSecond
            );

            if (currentLimit < _amount) revert IXERC20_NotHighEnoughLimits();

            _useMinterLimits(_caller, _amount);
        }
        _mint(_user, _amount);
    }

    /**
     * @notice Internal burn with caller validation and limit checking
     * @param _caller Address calling the burn function
     * @param _user Address to burn tokens from
     * @param _amount Amount to burn
     */
    function _burnWithCaller(address _caller, address _user, uint256 _amount) internal {
        if (_caller != lockbox) {
            uint256 currentLimit = _getCurrentLimit(
                bridges[_caller].burnerParams.currentLimit,
                bridges[_caller].burnerParams.maxLimit,
                bridges[_caller].burnerParams.timestamp,
                bridges[_caller].burnerParams.ratePerSecond
            );

            if (currentLimit < _amount) revert IXERC20_NotHighEnoughLimits();

            _useBurnerLimits(_caller, _amount);
        }
        _burn(_user, _amount);
    }

    /**
     * @notice Updates minting limit for a bridge
     * @param _bridge Bridge address
     * @param _limit New maximum minting limit
     */
    function _changeMinterLimit(address _bridge, uint256 _limit) internal {
        // If first time setting limit (timestamp == 0), initialize with full limit
        uint256 currentLimit;
        if (bridges[_bridge].minterParams.timestamp == 0) {
            currentLimit = _limit;
        } else {
            currentLimit = _getCurrentLimit(
                bridges[_bridge].minterParams.currentLimit,
                bridges[_bridge].minterParams.maxLimit,
                bridges[_bridge].minterParams.timestamp,
                bridges[_bridge].minterParams.ratePerSecond
            );
            // Cap at new limit if reducing
            currentLimit = currentLimit > _limit ? _limit : currentLimit;
        }

        bridges[_bridge].minterParams.timestamp = block.timestamp;
        bridges[_bridge].minterParams.ratePerSecond = _limit / _DURATION;
        bridges[_bridge].minterParams.maxLimit = _limit;
        bridges[_bridge].minterParams.currentLimit = currentLimit;
    }

    /**
     * @notice Updates burning limit for a bridge
     * @param _bridge Bridge address
     * @param _limit New maximum burning limit
     */
    function _changeBurnerLimit(address _bridge, uint256 _limit) internal {
        // If first time setting limit (timestamp == 0), initialize with full limit
        uint256 currentLimit;
        if (bridges[_bridge].burnerParams.timestamp == 0) {
            currentLimit = _limit;
        } else {
            currentLimit = _getCurrentLimit(
                bridges[_bridge].burnerParams.currentLimit,
                bridges[_bridge].burnerParams.maxLimit,
                bridges[_bridge].burnerParams.timestamp,
                bridges[_bridge].burnerParams.ratePerSecond
            );
            // Cap at new limit if reducing
            currentLimit = currentLimit > _limit ? _limit : currentLimit;
        }

        bridges[_bridge].burnerParams.timestamp = block.timestamp;
        bridges[_bridge].burnerParams.ratePerSecond = _limit / _DURATION;
        bridges[_bridge].burnerParams.maxLimit = _limit;
        bridges[_bridge].burnerParams.currentLimit = currentLimit;
    }

    /**
     * @notice Consumes minting limit for a bridge
     * @param _bridge Bridge address
     * @param _change Amount to consume from limit
     */
    function _useMinterLimits(address _bridge, uint256 _change) internal {
        uint256 currentLimit = _getCurrentLimit(
            bridges[_bridge].minterParams.currentLimit,
            bridges[_bridge].minterParams.maxLimit,
            bridges[_bridge].minterParams.timestamp,
            bridges[_bridge].minterParams.ratePerSecond
        );

        bridges[_bridge].minterParams.timestamp = block.timestamp;
        bridges[_bridge].minterParams.currentLimit = currentLimit - _change;
    }

    /**
     * @notice Consumes burning limit for a bridge
     * @param _bridge Bridge address
     * @param _change Amount to consume from limit
     */
    function _useBurnerLimits(address _bridge, uint256 _change) internal {
        uint256 currentLimit = _getCurrentLimit(
            bridges[_bridge].burnerParams.currentLimit,
            bridges[_bridge].burnerParams.maxLimit,
            bridges[_bridge].burnerParams.timestamp,
            bridges[_bridge].burnerParams.ratePerSecond
        );

        bridges[_bridge].burnerParams.timestamp = block.timestamp;
        bridges[_bridge].burnerParams.currentLimit = currentLimit - _change;
    }

    /**
     * @notice Calculates current available limit based on time elapsed
     * @param _currentLimit Last recorded limit
     * @param _maxLimit Maximum limit cap
     * @param _timestamp Last update timestamp
     * @param _ratePerSecond Rate of limit replenishment per second
     * @return Current available limit
     */
    function _getCurrentLimit(uint256 _currentLimit, uint256 _maxLimit, uint256 _timestamp, uint256 _ratePerSecond)
        internal
        view
        returns (uint256)
    {
        uint256 timeElapsed = block.timestamp - _timestamp;
        uint256 calculatedLimit = _currentLimit + (timeElapsed * _ratePerSecond);
        return calculatedLimit > _maxLimit ? _maxLimit : calculatedLimit;
    }

    /**
     * @dev Authorizes contract upgrades (UUPS pattern)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
