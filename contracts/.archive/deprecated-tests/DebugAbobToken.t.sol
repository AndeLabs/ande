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

contract DebugAbobToken is Test {
    AbobToken public abobToken;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    MockERC20 public usdcToken;
    MockOracle public mockOracle;

    address public admin = makeAddr("admin");
    address public user = makeAddr("user");

    function setUp() public {
        console.log("=== DEBUG ABOB TOKEN SETUP ===");

        try this._step1_deployMocks() {
            console.log("OK Step 1: Mocks deployed");
        } catch Error(string memory reason) {
            console.log("FAIL Step 1 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 1 failed: Unknown error");
            revert();
        }

        try this._step2_deployPriceOracle() {
            console.log("OK Step 2: PriceOracle deployed");
        } catch Error(string memory reason) {
            console.log("FAIL Step 2 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 2 failed: Unknown error");
            revert();
        }

        try this._step3_deployCollateralManager() {
            console.log("OK Step 3: CollateralManager deployed");
        } catch Error(string memory reason) {
            console.log("FAIL Step 3 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 3 failed: Unknown error");
            revert();
        }

        try this._step4_deployAbobToken() {
            console.log("OK Step 4: AbobToken deployed");
        } catch Error(string memory reason) {
            console.log("FAIL Step 4 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 4 failed: Unknown error");
            revert();
        }

        try this._step5_setupPriceFeeds() {
            console.log("OK Step 5: Price feeds setup");
        } catch Error(string memory reason) {
            console.log("FAIL Step 5 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 5 failed: Unknown error");
            revert();
        }

        try this._step6_addCollateral() {
            console.log("OK Step 6: Collateral added");
        } catch Error(string memory reason) {
            console.log("FAIL Step 6 failed:", reason);
            revert(reason);
        } catch {
            console.log("FAIL Step 6 failed: Unknown error");
            revert();
        }

        console.log("=== SETUP COMPLETED SUCCESSFULLY ===");
    }

    function _step1_deployMocks() external {
        console.log("Deploying mocks...");
        usdcToken = new MockERC20("USD Coin", "USDC", 6);
        mockOracle = new MockOracle(int256(1e6), 6); // $1 price feed (6 decimals for USDC)
        console.log("Mock USDC:", address(usdcToken));
        console.log("Mock Oracle:", address(mockOracle));
    }

    function _step2_deployPriceOracle() external {
        console.log("Deploying PriceOracle...");
        priceOracle = new PriceOracle();
        console.log("PriceOracle implementation:", address(priceOracle));

        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(priceOracle),
            abi.encodeWithSelector(PriceOracle.initialize.selector, admin)
        );
        priceOracle = PriceOracle(address(oracleProxy));
        console.log("PriceOracle proxy:", address(priceOracle));
    }

    function _step3_deployCollateralManager() external {
        console.log("Deploying CollateralManager...");
        collateralManager = new CollateralManager();
        console.log("CollateralManager implementation:", address(collateralManager));

        ERC1967Proxy collateralProxy = new ERC1967Proxy(
            address(collateralManager),
            abi.encodeWithSelector(
                CollateralManager.initialize.selector,
                admin,
                address(priceOracle)
            )
        );
        collateralManager = CollateralManager(address(collateralProxy));
        console.log("CollateralManager proxy:", address(collateralManager));
    }

    function _step4_deployAbobToken() external {
        console.log("Deploying AbobToken...");
        AbobToken implementation = new AbobToken();
        console.log("AbobToken implementation:", address(implementation));

        bytes memory initData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin,
            admin,
            admin,
            address(priceOracle),
            address(collateralManager),
            address(0) // No auction manager initially
        );
        console.log("Init data length:", initData.length);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        abobToken = AbobToken(payable(address(proxy)));
        console.log("AbobToken proxy:", address(abobToken));
    }

    function _step5_setupPriceFeeds() external {
        console.log("Setting up price feeds...");
        console.log("Admin address:", admin);
        console.log("PriceOracle owner:", priceOracle.owner());
        console.log("USDC token:", address(usdcToken));
        console.log("Mock oracle:", address(mockOracle));

        vm.startPrank(admin);
        try priceOracle.addSource(address(usdcToken), address(mockOracle), "Mock USDC Oracle") {
            console.log("addSource successful");
        } catch Error(string memory reason) {
            console.log("addSource failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("addSource low level error:");
            console.logBytes(lowLevelData);
            revert();
        }
        vm.stopPrank();

        // MockOracle owner is msg.sender from constructor, which is this test contract
        // So we need to call setPrice from this test contract context (without prank)
        try mockOracle.setPrice(1e6) {
            console.log("setPrice successful");
        } catch Error(string memory reason) {
            console.log("setPrice failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("setPrice low level error:");
            console.logBytes(lowLevelData);
            revert();
        }
        console.log("Price feeds configured");
    }

    function _step6_addCollateral() external {
        console.log("Adding USDC as collateral...");
        vm.startPrank(admin);
        collateralManager.addCollateral(
            address(usdcToken),
            15000, // 150% over-collateralization
            12500, // 125% liquidation threshold
            1_000_000 * 1e6, // 1M USDC debt ceiling
            100 * 1e6, // 100 USDC minimum deposit
            address(priceOracle)
        );
        vm.stopPrank();
        console.log("USDC collateral added");
    }

    function test_debug() public {
        console.log("Debug test passed");
    }
}