// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract DualTrackBurnEngine is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    IERC20 public andeToken;
    uint256 public lastScheduledBurnTimestamp;

    uint256 public constant SCHEDULE_PERIOD = 90 days;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address burner, address andeTokenAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(BURNER_ROLE, burner);

        require(andeTokenAddress != address(0), "ANDE token address cannot be zero");
        andeToken = IERC20(andeTokenAddress);
        lastScheduledBurnTimestamp = block.timestamp;
    }

    function impulsiveBurn(uint256 amount) public onlyRole(BURNER_ROLE) {
        uint256 currentBalance = andeToken.balanceOf(address(this));
        require(amount > 0, "Burn amount must be positive");
        require(amount <= currentBalance, "Burn amount exceeds balance");
        
        ERC20BurnableUpgradeable(address(andeToken)).burn(amount);
    }

    function scheduledBurn() public {
        require(block.timestamp >= lastScheduledBurnTimestamp + SCHEDULE_PERIOD, "Scheduled burn period not yet passed");
        uint256 currentBalance = andeToken.balanceOf(address(this));
        require(currentBalance > 0, "No tokens to burn");

        lastScheduledBurnTimestamp = block.timestamp;
        ERC20BurnableUpgradeable(address(andeToken)).burn(currentBalance);
    }

    // The following functions are required by UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
