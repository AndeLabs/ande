// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {P2POracle} from "../../src/P2POracle.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestCollateral is Test {
    AbobToken public abobToken;
    P2POracle public p2pAndeOracle;
    MockERC20 public ausd;
    MockERC20 public ande;
    MockOracle public abobOracle;

    address public admin = makeAddr("admin");
    address public finalizer = makeAddr("finalizer");

    uint256 public constant ORACLE_MIN_STAKE = 100e18;
    uint256 public constant ORACLE_EPOCH_DURATION = 1 hours;
    uint256 public constant ABOB_PRICE = 1 * 1e18;

    function setUp() public {
        // Deploy mocks
        ausd = new MockERC20("Mock AUSD", "mAUSD", 18);
        ande = new MockERC20("Mock ANDE", "mANDE", 18);
        abobOracle = new MockOracle(int256(ABOB_PRICE), 18);

        // Deploy P2POracle
        P2POracle p2pImpl = new P2POracle();
        bytes memory p2pInitData = abi.encodeWithSelector(
            P2POracle.initialize.selector, admin, address(ande), ORACLE_MIN_STAKE, ORACLE_EPOCH_DURATION
        );
        ERC1967Proxy p2pProxy = new ERC1967Proxy(address(p2pImpl), p2pInitData);
        p2pAndeOracle = P2POracle(address(p2pProxy));

        vm.startPrank(admin);
        p2pAndeOracle.grantRole(p2pAndeOracle.FINALIZER_ROLE(), finalizer);
        vm.stopPrank();

        // Deploy AbobToken
        AbobToken abobImpl = new AbobToken();
        bytes memory abobInitData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin, // admin
            admin, // pauser
            admin, // governance
            address(ausd),
            address(ande),
            address(0), // Sin CollateralManager - usa fallback local
            address(abobOracle),
            7000 // 70% collateral ratio
        );
        ERC1967Proxy abobProxy = new ERC1967Proxy(address(abobImpl), abobInitData);
        abobToken = AbobToken(payable(address(abobProxy)));
    }

    function test_addCollateral_direct() public {
        console.log("Testing addCollateral directly...");

        vm.startPrank(admin);

        console.log("Collateral address:", address(ande));
        console.log("P2POracle address:", address(p2pAndeOracle));

        try abobToken.addCollateral(
            address(ande),
            12000, // 120% collateral ratio
            11000, // 110% liquidation threshold
            1_000_000 * 1e18, // 1M ABOB debt ceiling
            100 * 1e18, // 100 ABOB minimum deposit
            address(p2pAndeOracle) // Usar P2P oracle para precios
        ) {
            console.log("SUCCESS: addCollateral worked!");
        } catch Error(string memory reason) {
            console.log("ERROR:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("LOW LEVEL ERROR:");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }
}