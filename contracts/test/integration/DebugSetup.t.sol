// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {P2POracle} from "../../src/P2POracle.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DebugSetup is Test {
    AbobToken public abobToken;
    P2POracle public p2pAndeOracle;
    MockERC20 public ausd;
    MockERC20 public ande;
    MockOracle public abobOracle;

    address public admin = makeAddr("admin");
    address public finalizer = makeAddr("finalizer");
    address public user = makeAddr("user");

    uint256 public constant ORACLE_MIN_STAKE = 100e18;
    uint256 public constant ORACLE_EPOCH_DURATION = 1 hours;
    uint256 public constant ABOB_PRICE = 1 * 1e18;

    function setUp() public {
        console.log("=== Iniciando setUp ===");

        try this._step1_deployMocks() {
            console.log("OK Step 1: Mocks desplegados correctamente");
        } catch Error(string memory reason) {
            console.log("FAIL Step 1 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 1 failed: Unknown error");
            revert();
        }

        try this._step2_deployP2POracle() {
            console.log("OK Step 2: P2POracle desplegado correctamente");
        } catch Error(string memory reason) {
            console.log("FAIL Step 2 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 2 failed: Unknown error");
            revert();
        }

        try this._step3_deployAbobToken() {
            console.log("OK Step 3: AbobToken desplegado correctamente");
        } catch Error(string memory reason) {
            console.log("FAIL Step 3 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 3 failed: Unknown error");
            revert();
        }

        try this._step4_configureCollateral() {
            console.log("OK Step 4: Colateral configurado correctamente");
        } catch Error(string memory reason) {
            console.log("FAIL Step 4 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 4 failed: Unknown error");
            revert();
        }

        try this._step5_prepareUser() {
            console.log("OK Step 5: Usuario preparado correctamente");
        } catch Error(string memory reason) {
            console.log("FAIL Step 5 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 5 failed: Unknown error");
            revert();
        }

        console.log("=== setUp completado exitosamente ===");
    }

    function _step1_deployMocks() external {
        console.log("Desplegando mocks...");
        ausd = new MockERC20("Mock AUSD", "mAUSD", 18);
        ande = new MockERC20("Mock ANDE", "mANDE", 18);
        abobOracle = new MockOracle(int256(ABOB_PRICE), 18);
        console.log("Mocks creados");
    }

    function _step2_deployP2POracle() external {
        console.log("Desplegando P2POracle...");
        P2POracle p2pImpl = new P2POracle();
        bytes memory p2pInitData = abi.encodeWithSelector(
            P2POracle.initialize.selector, admin, address(ande), ORACLE_MIN_STAKE, ORACLE_EPOCH_DURATION
        );
        ERC1967Proxy p2pProxy = new ERC1967Proxy(address(p2pImpl), p2pInitData);
        p2pAndeOracle = P2POracle(address(p2pProxy));

        vm.startPrank(admin);
        p2pAndeOracle.grantRole(p2pAndeOracle.FINALIZER_ROLE(), finalizer);
        vm.stopPrank();
        console.log("P2POracle configurado");
    }

    function _step3_deployAbobToken() external {
        console.log("Desplegando AbobToken...");
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
        console.log("AbobToken desplegado");
    }

    function _step4_configureCollateral() external {
        console.log("Configurando colateral ANDE...");

        vm.startPrank(admin);
        abobToken.addCollateral(
            address(ande),
            12000, // 120% collateral ratio
            11000, // 110% liquidation threshold (debe ser >= 100%)
            1_000_000 * 1e18, // 1M ABOB debt ceiling
            100 * 1e18, // 100 ABOB minimum deposit
            address(p2pAndeOracle) // Usar P2P oracle para precios
        );
        vm.stopPrank();
        console.log("Colateral ANDE configurado");
    }

    function _step5_prepareUser() external {
        console.log("Preparando usuario...");
        ausd.mint(user, 1000e18);
        ande.mint(user, 1000e18);
        vm.startPrank(user);
        ausd.approve(address(abobToken), type(uint256).max);
        ande.approve(address(abobToken), type(uint256).max);
        vm.stopPrank();
        console.log("Usuario preparado");
    }

    function test_debugSetUp() public {
        console.log("Debug setup test passed");
    }
}