// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {P2POracleV2} from "../../src/P2POracleV2.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract P2POracleV2Test is Test {
    // === Contratos ===
    P2POracleV2 public oracle;
    MockERC20 public andeToken;

    // === Actores ===
    address public admin = makeAddr("admin");
    address public reporter1 = makeAddr("reporter1");
    address public attacker = makeAddr("attacker");
    address public treasury = makeAddr("treasury");

    // === Constantes ===
    uint256 public constant INITIAL_STAKE = 100e18;
    uint256 public constant EPOCH_DURATION = 1 hours;

    function setUp() public {
        // 1. Deploy tokens y mocks
        andeToken = new MockERC20("Ande Token", "ANDE", 18);

        // 2. Deploy contract (con proxy)
        P2POracleV2 oracleImpl = new P2POracleV2();
        bytes memory initData = abi.encodeWithSelector(
            P2POracleV2.initialize.selector, admin, address(andeToken), INITIAL_STAKE, EPOCH_DURATION
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(oracleImpl), initData);
        oracle = P2POracleV2(address(proxy));

        // 3. Setup inicial de tesorería
        vm.prank(admin);
        oracle.setTreasury(treasury);

        // 4. Fondos para el reportero
        andeToken.mint(reporter1, INITIAL_STAKE);
        vm.prank(reporter1);
        andeToken.approve(address(oracle), INITIAL_STAKE);
    }

    // =========================================
    // DEPLOYMENT & SETUP TESTS
    // =========================================

    function test_Deployment_InitialStateCorrect() public {
        assertTrue(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin), "Admin should have admin role");
        assertTrue(oracle.hasRole(oracle.FINALIZER_ROLE(), admin), "Admin should also have finalizer role initially");
        assertTrue(oracle.hasRole(oracle.SLASHER_ROLE(), admin), "Admin should also have slasher role initially");
        assertEq(address(oracle.andeToken()), address(andeToken), "Incorrect ANDE token address");
        assertEq(oracle.minStake(), INITIAL_STAKE, "Incorrect min stake");
        assertEq(oracle.reportEpochDuration(), EPOCH_DURATION, "Incorrect epoch duration");
        assertEq(oracle.treasury(), treasury, "Incorrect treasury address");
    }

    // =========================================
    // SLASH FUNCTION TESTS
    // =========================================

    function test_Slash_WhenNotSlasher_Reverts() public {
        // Arrange: Registrar un reportero primero
        vm.prank(reporter1);
        oracle.register();

        // Act & Assert: Expect any revert since only the slasher can call this.
        vm.expectRevert();
        vm.prank(attacker);
        oracle.slash(reporter1);
    }

    function test_Slash_WhenSlasher_Success() public {
        // Arrange: Registrar un reportero
        vm.prank(reporter1);
        oracle.register();

        (bool isRegisteredBefore,,,) = oracle.reporters(reporter1);
        assertTrue(isRegisteredBefore, "Reporter should be registered initially");
        assertEq(andeToken.balanceOf(address(oracle)), INITIAL_STAKE, "Oracle should hold the stake");

        uint256 treasuryBalanceBefore = andeToken.balanceOf(treasury);

        // Act: El slasher (admin en este caso) autorizado ejecuta la función
        vm.prank(admin);
        oracle.slash(reporter1);

        // Assert
        // 1. El reportero ya no está registrado
        (bool isRegisteredAfter,,,) = oracle.reporters(reporter1);
        assertFalse(isRegisteredAfter, "Reporter should be unregistered after slash");

        // 2. El stake se ha transferido a la tesorería
        assertEq(andeToken.balanceOf(address(oracle)), 0, "Oracle should have no stake left");
        assertEq(
            andeToken.balanceOf(treasury), treasuryBalanceBefore + INITIAL_STAKE, "Treasury should receive the stake"
        );
    }

    function test_Slash_OnNonReporter_Reverts() public {
        // Arrange: El 'attacker' no es un reportero registrado

        // Act & Assert
        vm.expectRevert("Not a registered reporter");
        vm.prank(admin); // Prank como el slasher
        oracle.slash(attacker);
    }

    function test_Slash_EmitsSlashedEvent() public {
        // Arrange: Registrar un reportero
        vm.prank(reporter1);
        oracle.register();

        // Expect event
        // event ReporterSlashed(address indexed reporter, uint256 amount);
        vm.expectEmit(true, false, false, true);
        emit P2POracleV2.ReporterSlashed(reporter1, INITIAL_STAKE);

        // Act
        vm.prank(admin); // Prank como el slasher
        oracle.slash(reporter1);
    }
}
