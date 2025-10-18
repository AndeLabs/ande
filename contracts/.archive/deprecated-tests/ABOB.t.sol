// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockOracle} from "../src/mocks/MockOracle.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {AuctionManager} from "../src/AuctionManager.sol";
import {AndeTimelockController} from "../src/governance/AndeTimelockController.sol";

contract ABOBTest is Test {
    // ==================== TEST ADDRESSES ====================
    address private constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address private constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // ==================== MOCK TOKENS ====================
    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20 public ande;
    MockERC20 public abob;

    // ==================== MOCK ORACLES ====================
    MockOracle public usdcOracle;
    MockOracle public usdcOracle2; // Second source for median calculation
    MockOracle public wethOracle;
    MockOracle public wethOracle2; // Second source for median calculation
    MockOracle public andeOracle;
    MockOracle public andeOracle2; // Second source for median calculation

    // ==================== CONTRACTS ====================
    AndeTimelockController public timelock;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    AbobToken public abobToken;
    AuctionManager public auctionManager;

    // ==================== SETUP ====================
    function setUp() public {
        vm.startPrank(DEPLOYER);

        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        ande = new MockERC20("Ande Token", "ANDE", 18);
        abob = new MockERC20("Andean Boliviano", "ABOB", 18);

        // Deploy mock oracles (initialPrice, decimals) - need at least 2 sources per token
        usdcOracle = new MockOracle(int256(1e8), 8);     // $1 with 8 decimals
        usdcOracle2 = new MockOracle(int256(1e8), 8);    // $1 with 8 decimals (same price)
        wethOracle = new MockOracle(int256(3000e8), 8);  // $3000 with 8 decimals
        wethOracle2 = new MockOracle(int256(3000e8), 8); // $3000 with 8 decimals (same price)
        andeOracle = new MockOracle(int256(1e8), 8);     // $1 with 8 decimals
        andeOracle2 = new MockOracle(int256(1e8), 8);    // $1 with 8 decimals (same price)

        // Prices are already set in constructor

        // Deploy timelock with proxy
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = DEPLOYER;
        executors[0] = address(0);

        AndeTimelockController timelockImpl = new AndeTimelockController();
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            abi.encodeWithSelector(
                AndeTimelockController.initialize.selector,
                1 days,
                proposers,
                executors,
                DEPLOYER
            )
        );
        timelock = AndeTimelockController(payable(address(timelockProxy)));

        // Deploy contracts
        _deployContracts();

        // Setup initial state
        _setupInitialState();

        vm.stopPrank();
    }

    function _deployContracts() internal {
        // Deploy Price Oracle
        priceOracle = new PriceOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(priceOracle),
            abi.encodeWithSelector(PriceOracle.initialize.selector, DEPLOYER)
        );
        priceOracle = PriceOracle(address(oracleProxy));

        // Deploy Collateral Manager
        collateralManager = new CollateralManager();
        ERC1967Proxy collateralProxy = new ERC1967Proxy(
            address(collateralManager),
            abi.encodeWithSelector(
                CollateralManager.initialize.selector,
                DEPLOYER,  // defaultAdmin - for test convenience
                address(priceOracle)
            )
        );
        collateralManager = CollateralManager(address(collateralProxy));

        // Deploy ABOB Token
        abobToken = new AbobToken();
        ERC1967Proxy abobProxy = new ERC1967Proxy(
            address(abobToken),
            abi.encodeWithSelector(
                AbobToken.initialize.selector,
                DEPLOYER,               // _admin
                DEPLOYER,               // _pauser
                DEPLOYER,               // _governance (for test convenience)
                address(priceOracle),   // _priceOracle
                address(collateralManager), // _collateralManager
                DEPLOYER                // _liquidationManager
            )
        );
        abobToken = AbobToken(payable(address(abobProxy)));

        // Deploy Auction Manager
        auctionManager = new AuctionManager();
        ERC1967Proxy auctionProxy = new ERC1967Proxy(
            address(auctionManager),
            abi.encodeWithSelector(
                AuctionManager.initialize.selector,
                DEPLOYER,  // defaultAdmin
                address(abobToken),
                address(collateralManager)
            )
        );
        auctionManager = AuctionManager(address(auctionProxy));
    }

    function _setupInitialState() internal {
        // Add price sources to oracle - need at least 2 sources per token for median calculation
        priceOracle.addSource(address(usdc), address(usdcOracle), "Mock USDC 1");
        priceOracle.addSource(address(usdc), address(usdcOracle2), "Mock USDC 2");
        priceOracle.addSource(address(weth), address(wethOracle), "Mock WETH 1");
        priceOracle.addSource(address(weth), address(wethOracle2), "Mock WETH 2");
        priceOracle.addSource(address(ande), address(andeOracle), "Mock ANDE 1");
        priceOracle.addSource(address(ande), address(andeOracle2), "Mock ANDE 2");

        // Update prices
        priceOracle.updatePrice(address(usdc));
        priceOracle.updatePrice(address(weth));
        priceOracle.updatePrice(address(ande));

        // Add collaterals
        collateralManager.addCollateral(
            address(usdc),
            15000, // 150%
            12500, // 125%
            10_000_000 * 1e18, // 10M ABOB ceiling (normalized to 18 decimals)
            100 * 1e6,
            address(priceOracle)
        );

        collateralManager.addCollateral(
            address(weth),
            16000, // 160%
            13000, // 130%
            10_000_000 * 1e18, // 10M ABOB ceiling (normalized to 18 decimals)
            1 * 1e17,
            address(priceOracle)
        );

        // Grant roles
        abobToken.grantRole(abobToken.LIQUIDATION_MANAGER_ROLE(), address(auctionManager));

        // Note: Collaterals already added to CollateralManager above
        // AbobToken will query CollateralManager when needed

        // Fund users with tokens
        usdc.mint(USER1, 10000 * 1e6);
        weth.mint(USER1, 10 * 1e18);
        usdc.mint(USER2, 10000 * 1e6);
        weth.mint(USER2, 10 * 1e18);
    }

    // ==================== BASIC FUNCTIONALITY TESTS ====================

    function testDeployment() public {
        assertEq(address(priceOracle), address(priceOracle), "PriceOracle not deployed");
        assertEq(address(collateralManager), address(collateralManager), "CollateralManager not deployed");
        assertEq(address(abobToken), address(abobToken), "AbobToken not deployed");
        assertEq(address(auctionManager), address(auctionManager), "AuctionManager not deployed");
    }

    function testPriceOracle() public {
        uint256 usdcPrice = priceOracle.getMedianPrice(address(usdc));
        uint256 wethPrice = priceOracle.getMedianPrice(address(weth));
        uint256 andePrice = priceOracle.getMedianPrice(address(ande));

        assertEq(usdcPrice, 1e18, "USDC price incorrect");
        assertEq(wethPrice, 3000e18, "WETH price incorrect");
        assertEq(andePrice, 1e18, "ANDE price incorrect");

        assertTrue(priceOracle.isValidPrice(address(usdc)), "USDC price should be valid");
        assertTrue(priceOracle.isValidPrice(address(weth)), "WETH price should be valid");
        assertTrue(priceOracle.isValidPrice(address(ande)), "ANDE price should be valid");
    }

    function testCollateralManager() public {
        (bool isSupported, uint256 ratio, uint256 threshold, uint256 ceiling) =
            collateralManager.getCollateralInfo(address(usdc));

        assertTrue(isSupported, "USDC should be supported");
        assertEq(ratio, 15000, "USDC ratio incorrect");
        assertEq(threshold, 12500, "USDC threshold incorrect");
        assertEq(ceiling, 10_000_000 * 1e18, "USDC ceiling incorrect"); // Ceiling in ABOB (18 decimals)
    }

    function testBasicVaultOperations() public {
        vm.startPrank(USER1);

        // Approve tokens
        usdc.approve(address(abobToken), 1000 * 1e6);

        // Deposit collateral
        abobToken.depositCollateral(address(usdc), 1000 * 1e6);

        // Check vault info
        (uint256 collateralValue, uint256 debt, uint256 ratio) =
            abobToken.getUserVaultInfo(USER1);

        assertEq(collateralValue, 1000 * 1e18, "Collateral value incorrect");
        assertEq(debt, 0, "Debt should be zero initially");
        assertEq(ratio, 0, "Ratio should be 0 when no debt");

        // Mint ABOB
        abobToken.mintAbob(500 * 1e18);

        // Check vault info after minting
        (collateralValue, debt, ratio) = abobToken.getUserVaultInfo(USER1);

        assertEq(collateralValue, 1000 * 1e18, "Collateral value should be unchanged");
        assertEq(debt, 500 * 1e18, "Debt should be 500 ABOB");
        assertEq(ratio, 20000, "Ratio should be 200% (1000/500)");

        // Burn ABOB
        abobToken.repayDebt(200 * 1e18);

        // Check vault info after burning
        (collateralValue, debt, ratio) = abobToken.getUserVaultInfo(USER1);

        assertEq(collateralValue, 1000 * 1e18, "Collateral value should be unchanged");
        assertEq(debt, 300 * 1e18, "Debt should be 300 ABOB");
        assertEq(ratio, 33333, "Ratio should be ~333% (1000/300)");

        vm.stopPrank();
    }

    function testCombinedDepositAndMint() public {
        vm.startPrank(USER1);

        // Approve tokens
        usdc.approve(address(abobToken), 2000 * 1e6);

        // Combined operation
        abobToken.depositCollateralAndMint(address(usdc), 2000 * 1e6, 1000 * 1e18);

        // Check results
        (uint256 collateralValue, uint256 debt, uint256 ratio) =
            abobToken.getUserVaultInfo(USER1);

        assertEq(collateralValue, 2000 * 1e18, "Collateral value incorrect");
        assertEq(debt, 1000 * 1e18, "Debt incorrect");
        assertEq(ratio, 20000, "Ratio should be 200%");
        assertEq(abobToken.balanceOf(USER1), 1000 * 1e18, "ABOB balance incorrect");

        vm.stopPrank();
    }

    function testWithdrawAndRepay() public {
        vm.startPrank(USER1);

        // Setup initial position
        usdc.approve(address(abobToken), 2000 * 1e6);
        abobToken.depositCollateralAndMint(address(usdc), 2000 * 1e6, 1000 * 1e18);

        // Approve ABOB for repayment
        abobToken.approve(address(abobToken), 500 * 1e18);

        // Withdraw and repay
        abobToken.withdrawCollateralAndRepayDebt(address(usdc), 500 * 1e6, 500 * 1e18);

        // Check results
        (uint256 collateralValue, uint256 debt, uint256 ratio) =
            abobToken.getUserVaultInfo(USER1);

        assertEq(collateralValue, 1500 * 1e18, "Collateral value should be 1500");
        assertEq(debt, 500 * 1e18, "Debt should be 500");
        assertEq(ratio, 30000, "Ratio should be 300% (1500/500)");
        assertEq(abobToken.balanceOf(USER1), 500 * 1e18, "ABOB balance should be 500");

        vm.stopPrank();
    }

    function testUndercollateralizedVault() public {
        vm.startPrank(USER1);

        // Setup position
        usdc.approve(address(abobToken), 1500 * 1e6);
        abobToken.depositCollateralAndMint(address(usdc), 1500 * 1e6, 1000 * 1e18);

        // Drop USDC price to trigger undercollateralization
        vm.startPrank(DEPLOYER);
        usdcOracle.setPrice(0.7e8); // $0.70 with 8 decimals (makes vault undercollateralized)
        usdcOracle2.setPrice(0.7e8); // Update second oracle too for median calculation
        priceOracle.updatePrice(address(usdc));
        vm.stopPrank();

        vm.startPrank(USER1);

        // Try to withdraw - should fail due to undercollateralization
        vm.expectRevert();
        abobToken.withdrawCollateral(address(usdc), 200 * 1e6);

        vm.stopPrank();
    }

    function testSystemInfo() public {
        vm.startPrank(USER1);
        usdc.approve(address(abobToken), 2000 * 1e6);
        abobToken.depositCollateralAndMint(address(usdc), 2000 * 1e6, 1000 * 1e18);
        vm.stopPrank();

        (uint256 totalCollateral, uint256 totalDebt, uint256 systemRatio) =
            abobToken.getSystemInfo();

        assertEq(totalCollateral, 2000 * 1e18, "Total collateral incorrect");
        assertEq(totalDebt, 1000 * 1e18, "Total debt incorrect");
        assertEq(systemRatio, 20000, "System ratio should be 200%");
    }

    // ==================== EDGE CASE TESTS ====================

    function testZeroAmounts() public {
        vm.startPrank(USER1);

        vm.expectRevert();
        abobToken.depositCollateral(address(usdc), 0);

        vm.expectRevert();
        abobToken.mintAbob(0);

        vm.expectRevert();
        abobToken.repayDebt(0);

        vm.stopPrank();
    }

    function testUnsupportedCollateral() public {
        vm.startPrank(USER1);

        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);
        unsupportedToken.mint(USER1, 1000 * 1e18);
        unsupportedToken.approve(address(abobToken), 1000 * 1e18);

        vm.expectRevert();
        abobToken.depositCollateral(address(unsupportedToken), 1000 * 1e18);

        vm.stopPrank();
    }

    function testInsufficientCollateral() public {
        vm.startPrank(USER1);

        usdc.approve(address(abobToken), 1000 * 1e6);
        abobToken.depositCollateral(address(usdc), 1000 * 1e6);

        // Try to mint more than allowed (would require >150% ratio)
        vm.expectRevert();
        abobToken.mintAbob(700 * 1e18); // Would need ~1050 USDC

        vm.stopPrank();
    }
}