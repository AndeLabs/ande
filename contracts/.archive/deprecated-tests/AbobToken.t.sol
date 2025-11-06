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

/**
 * @title Test básico para AbobToken CDP
 * @notice Verifica funcionalidad core del sistema CDP
 */
contract AbobTokenCDPTest is Test {
    // === Contratos ===
    AbobToken public abobToken;
    PriceOracle public priceOracle;
    CollateralManager public collateralManager;
    AuctionManager public auctionManager;
    MockERC20 public usdcToken;
    MockERC20 public wethToken;
    MockOracle public mockOracle;

    // === Actores ===
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");

    // === Constantes ===
    uint256 public constant INITIAL_RATIO = 15000; // 150%
    uint256 public constant MINT_AMOUNT = 1000e18;

    function setUp() public {
        // 1. Deploy mock tokens
        usdcToken = new MockERC20("USD Coin", "USDC", 6);
        wethToken = new MockERC20("Wrapped Ether", "WETH", 18);
        mockOracle = new MockOracle(int256(1e6), 6); // $1 price feed (6 decimals for USDC)

        // 2. Deploy infrastructure contracts
        priceOracle = new PriceOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(priceOracle),
            abi.encodeWithSelector(PriceOracle.initialize.selector, admin)
        );
        priceOracle = PriceOracle(address(oracleProxy));

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

        // 3. Deploy AbobToken (without auction manager for now to avoid circular dependency)
        AbobToken implementation = new AbobToken();
        bytes memory initData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin,
            admin,
            admin,
            address(priceOracle),
            address(collateralManager),
            address(0) // No auction manager initially
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        abobToken = AbobToken(payable(address(proxy)));

        // 4. Setup price feeds
        vm.startPrank(admin);
        priceOracle.addSource(address(usdcToken), address(mockOracle), "Mock USDC Oracle");
        vm.stopPrank();

        // MockOracle owner is this test contract, so call setPrice directly
        mockOracle.setPrice(1e6); // $1 USDC (6 decimals)

        // 5. Add USDC as collateral
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

        // 6. Setup user balances
        usdcToken.mint(user, 10000e6);
        wethToken.mint(user, 10e18);

        vm.startPrank(user);
        usdcToken.approve(address(abobToken), type(uint256).max);
        wethToken.approve(address(abobToken), type(uint256).max);
        vm.stopPrank();
    }

    function test_Deployment_InitialState() public view {
        assertTrue(abobToken.hasRole(abobToken.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(abobToken.name(), "Andean Boliviano");
        assertEq(abobToken.symbol(), "ABOB");
    }

    function test_UserHasVaultByDefault() public view {
        // Vaults are created automatically when first needed
        (, uint256 debt, uint256 ratio) = abobToken.getUserVaultInfo(user);
        assertEq(debt, 0);
        assertEq(ratio, 0);
    }

    function test_UserCanDepositCollateral() public {
        uint256 depositAmount = 1000e6; // 1000 USDC (6 decimals)
        vm.prank(user);
        abobToken.depositCollateral(address(usdcToken), depositAmount);

        (uint256 collateralValue, uint256 debt,) = abobToken.getUserVaultInfo(user);
        // Value should be normalized to 18 decimals: 1000 USDC * 10^12 * $1 / 10^18 = 1000e18
        assertEq(collateralValue, 1000e18); // 1000 USDC worth of value, normalized to 18 decimals
        assertEq(debt, 0);
    }

    function test_UserCanMintAbob() public {
        // Deposit collateral
        uint256 collateralAmount = 2000e6; // 2000 USDC (200% collateralization)
        vm.prank(user);
        abobToken.depositCollateral(address(usdcToken), collateralAmount);

        // Mint ABOB
        uint256 mintAmount = 1000e18;
        vm.prank(user);
        abobToken.mintAbob(mintAmount);

        (uint256 collateralValue, uint256 debt, uint256 ratio) = abobToken.getUserVaultInfo(user);
        assertEq(debt, mintAmount);
        assertEq(ratio, 20000); // 200% ratio
        assertEq(abobToken.balanceOf(user), mintAmount);
    }

    function test_UserCanRepayDebt() public {
        // Setup: deposit and mint
        uint256 collateralAmount = 2000e6;
        uint256 mintAmount = 1000e18;

        vm.startPrank(user);
        abobToken.depositCollateral(address(usdcToken), collateralAmount);
        abobToken.mintAbob(mintAmount);

        // Repay debt
        abobToken.repayDebt(mintAmount);
        vm.stopPrank();

        (, uint256 debt, uint256 ratio) = abobToken.getUserVaultInfo(user);
        assertEq(debt, 0);
        assertEq(ratio, 0);
    }

    function test_CollateralRatioEnforcement() public {
        // Deposit minimal collateral
        uint256 collateralAmount = 1500e6; // 1500 USDC (150% of 1000)
        vm.prank(user);
        abobToken.depositCollateral(address(usdcToken), collateralAmount);

        // Try to mint more than allowed
        vm.prank(user);
        vm.expectRevert();
        abobToken.mintAbob(1100e18); // Would need 165% collateral, only have 150%
    }

    function test_EmergencyMode() public {
        // Test emergency pause (using existing pause function)
        vm.prank(admin);
        abobToken.pause();

        // Operations should be blocked
        vm.prank(user);
        vm.expectRevert();
        abobToken.mintAbob(100e18);
    }
}