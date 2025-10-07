// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {PriceOracle} from "../../src/PriceOracle.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {AuctionManager} from "../../src/AuctionManager.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DebugSetupTest is Test {
    // === Contratos ===
    AbobToken public abobToken;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    AuctionManager public auctionManager;
    MockERC20 public usdcToken;
    MockOracle public mockOracle;

    // === Actores ===
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");

    function setUp() public {
        console.log("=== SETUP START ===");
        console.log("Test contract address:", address(this));
        console.log("Admin address:", admin);
        console.log("User address:", user);

        // 1. Deploy mock tokens
        console.log("=== 1. DEPLOYING MOCK TOKENS ===");
        usdcToken = new MockERC20("USD Coin", "USDC", 6);
        mockOracle = new MockOracle(int256(1e6), 6);

        // 2. Deploy PriceOracle
        console.log("=== 2. DEPLOYING PRICE ORACLE ===");
        priceOracle = new PriceOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(priceOracle),
            abi.encodeWithSelector(PriceOracle.initialize.selector)
        );
        priceOracle = PriceOracle(address(oracleProxy));
        console.log("PriceOracle owner:", priceOracle.owner());

        // 3. Test PriceOracle owner
        console.log("=== 3. TESTING PRICE ORACLE OWNER ===");
        try priceOracle.addSource(address(usdcToken), address(mockOracle), "Mock USDC Oracle") {
            console.log("PriceOracle.addSource succeeded");
        } catch Error(string memory reason) {
            console.log("PriceOracle.addSource failed:", reason);
        } catch {
            console.log("PriceOracle.addSource failed with unknown error");
        }

        // 4. Deploy CollateralManager
        console.log("=== 4. DEPLOYING COLLATERAL MANAGER ===");
        collateralManager = new CollateralManager();
        ERC1967Proxy collateralProxy = new ERC1967Proxy(
            address(collateralManager),
            abi.encodeWithSelector(
                CollateralManager.initialize.selector,
                admin,
                address(priceOracle)
            )
        );
        collateralManager = CollateralManager(address(collateralProxy));
        console.log("CollateralManager owner:", collateralManager.owner());

        // 5. Test CollateralManager owner
        console.log("=== 5. TESTING COLLATERAL MANAGER OWNER ===");
        vm.startPrank(admin);
        try collateralManager.addCollateral(
            address(usdcToken),
            15000,
            12500,
            1_000_000 * 1e6,
            100 * 1e6,
            address(priceOracle)
        ) {
            console.log("CollateralManager.addCollateral succeeded");
        } catch Error(string memory reason) {
            console.log("CollateralManager.addCollateral failed:", reason);
        } catch {
            console.log("CollateralManager.addCollateral failed with unknown error");
        }
        vm.stopPrank();

        // 6. Deploy AbobToken
        console.log("=== 6. DEPLOYING ABOB TOKEN ===");
        AbobToken implementation = new AbobToken();
        bytes memory initData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin,
            admin,
            admin,
            address(priceOracle),
            address(collateralManager),
            address(0) // No auction manager yet
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        abobToken = AbobToken(payable(address(proxy)));
        console.log("AbobToken deployed at:", address(abobToken));

        // 7. Test AbobToken roles
        console.log("=== 7. TESTING ABOB TOKEN ROLES ===");
        bool hasAdminRole = abobToken.hasRole(abobToken.DEFAULT_ADMIN_ROLE(), admin);
        bool testContractHasAdminRole = abobToken.hasRole(abobToken.DEFAULT_ADMIN_ROLE(), address(this));
        console.log("Admin has DEFAULT_ADMIN_ROLE:", hasAdminRole);
        console.log("Test contract has DEFAULT_ADMIN_ROLE:", testContractHasAdminRole);

        // 8. Test granting a role
        console.log("=== 8. TESTING ROLE GRANTING ===");
        bytes32 liqManagerRole = abobToken.LIQUIDATION_MANAGER_ROLE();
        console.log("LIQUIDATION_MANAGER_ROLE:", uint256(liqManagerRole));

        vm.startPrank(admin);
        try abobToken.grantRole(liqManagerRole, address(this)) {
            console.log("Granting LIQUIDATION_MANAGER_ROLE to test contract succeeded");
        } catch Error(string memory reason) {
            console.log("Granting role failed:", reason);
        } catch {
            console.log("Granting role failed with unknown error");
        }
        vm.stopPrank();
    }

    function test_debugSetup() public view {
        assertTrue(true, "Setup completed");
    }
}