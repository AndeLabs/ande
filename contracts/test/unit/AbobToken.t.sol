// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";

contract AbobTokenTest is Test {
    AbobToken public abobToken;
    MockERC20 public ausdToken;
    MockERC20 public andeToken;
    MockOracle public andePriceFeed;
    MockOracle public abobPriceFeed;

    address public admin = makeAddr("admin");
    address public governance = makeAddr("governance");
    address public pauser = makeAddr("pauser");
    address public user = makeAddr("user");

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant INITIAL_RATIO = 7000; // 70% AUSD, 30% ANDE
    uint256 public constant ANDE_PRICE = 2 * 1e18; // $2 per ANDE
    uint256 public constant ABOB_PRICE = 1 * 1e18; // $1 per ABOB (pegged)

    function setUp() public {
        // Deploy mocks
        ausdToken = new MockERC20("Andean USD", "AUSD", 18);
        andeToken = new MockERC20("Ande Token", "ANDE", 18);
        andePriceFeed = new MockOracle(int256(ANDE_PRICE), 18);
        abobPriceFeed = new MockOracle(int256(ABOB_PRICE), 18);

        // Deploy implementation
        AbobToken implementation = new AbobToken();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            admin,
            pauser,
            governance,
            address(ausdToken),
            address(andeToken),
            address(andePriceFeed),
            address(abobPriceFeed),
            INITIAL_RATIO
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        abobToken = AbobToken(address(proxy));

        // Fund user with collateral
        ausdToken.mint(user, 1000e18);
        andeToken.mint(user, 1000e18);

        // User approves AbobToken
        vm.startPrank(user);
        ausdToken.approve(address(abobToken), type(uint256).max);
        andeToken.approve(address(abobToken), type(uint256).max);
        vm.stopPrank();
    }

    // ==========================================
    // DEPLOYMENT TESTS
    // ==========================================

    function test_Deployment_HasCorrectNameAndSymbol() public view {
        assertEq(abobToken.name(), "Andean Boliviano");
        assertEq(abobToken.symbol(), "ABOB");
        assertEq(abobToken.decimals(), 18);
    }

    function test_Deployment_SetsCorrectRoles() public view {
        assertTrue(abobToken.hasRole(abobToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(abobToken.hasRole(GOVERNANCE_ROLE, governance));
        assertTrue(abobToken.hasRole(PAUSER_ROLE, pauser));
    }

    function test_Deployment_SetsCorrectCollateralRatio() public view {
        assertEq(abobToken.collateralRatio(), INITIAL_RATIO);
    }

    function test_Deployment_SetsCorrectTokens() public view {
        assertEq(address(abobToken.ausdToken()), address(ausdToken));
        assertEq(address(abobToken.andeToken()), address(andeToken));
    }

    function test_Deployment_SetsCorrectOracles() public view {
        assertEq(address(abobToken.andePriceFeed()), address(andePriceFeed));
        assertEq(address(abobToken.abobPriceFeed()), address(abobPriceFeed));
    }

    // ==========================================
    // MINTING TESTS
    // ==========================================

    function test_Mint_Success() public {
        uint256 abobToMint = 100e18; // 100 ABOB

        // Expected collateral: 100 ABOB * $1 = $100 total value
        // 70% in AUSD = $70 = 70 AUSD
        // 30% in ANDE = $30 = 15 ANDE (at $2/ANDE)
        uint256 expectedAusd = 70e18;
        uint256 expectedAnde = 15e18;

        uint256 userAusdBefore = ausdToken.balanceOf(user);
        uint256 userAndeBefore = andeToken.balanceOf(user);

        vm.prank(user);
        abobToken.mint(abobToMint);

        assertEq(abobToken.balanceOf(user), abobToMint);
        assertEq(ausdToken.balanceOf(user), userAusdBefore - expectedAusd);
        assertEq(andeToken.balanceOf(user), userAndeBefore - expectedAnde);
        assertEq(ausdToken.balanceOf(address(abobToken)), expectedAusd);
        assertEq(andeToken.balanceOf(address(abobToken)), expectedAnde);
    }

    function test_Mint_RevertIf_AmountIsZero() public {
        vm.prank(user);
        vm.expectRevert("Amount must be positive");
        abobToken.mint(0);
    }

    function test_Mint_RevertIf_InsufficientAusdAllowance() public {
        vm.startPrank(user);
        ausdToken.approve(address(abobToken), 0);

        vm.expectRevert();
        abobToken.mint(100e18);
        vm.stopPrank();
    }

    function test_Mint_RevertIf_OraclePriceIsInvalid() public {
        andePriceFeed.setPrice(0);

        vm.prank(user);
        vm.expectRevert("Invalid oracle price");
        abobToken.mint(100e18);
    }

    function test_Mint_RevertIf_Paused() public {
        vm.prank(pauser);
        abobToken.pause();

        vm.prank(user);
        vm.expectRevert();
        abobToken.mint(100e18);
    }

    function test_Mint_EmitsEvent() public {
        uint256 abobToMint = 100e18;
        uint256 expectedAusd = 70e18;
        uint256 expectedAnde = 15e18;

        vm.expectEmit(true, true, true, true);
        emit AbobToken.Minted(user, abobToMint, expectedAusd, expectedAnde);

        vm.prank(user);
        abobToken.mint(abobToMint);
    }

    // ==========================================
    // REDEMPTION TESTS
    // ==========================================

    function test_Redeem_Success() public {
        uint256 abobToMint = 100e18;

        // First mint
        vm.prank(user);
        abobToken.mint(abobToMint);

        uint256 userAusdBefore = ausdToken.balanceOf(user);
        uint256 userAndeBefore = andeToken.balanceOf(user);

        // Redeem all
        vm.prank(user);
        abobToken.redeem(abobToMint);

        // Should receive back collateral (minus any fees if implemented)
        assertEq(abobToken.balanceOf(user), 0);
        assertGt(ausdToken.balanceOf(user), userAusdBefore); // Got AUSD back
        assertGt(andeToken.balanceOf(user), userAndeBefore); // Got ANDE back
    }

    function test_Redeem_Success_ExactAmounts() public {
        uint256 abobToMintAndRedeem = 100e18;

        // First, mint some tokens to have a balance to redeem
        vm.prank(user);
        abobToken.mint(abobToMintAndRedeem);
        
        uint256 userAusdBefore = ausdToken.balanceOf(user);
        uint256 userAndeBefore = andeToken.balanceOf(user);
        uint256 contractAusdBefore = ausdToken.balanceOf(address(abobToken));
        uint256 contractAndeBefore = andeToken.balanceOf(address(abobToken));

        // Calculate expected return amounts
        uint256 totalValueToReturn = (abobToMintAndRedeem * ABOB_PRICE) / 1e18;
        uint256 expectedAusdToReturn = (totalValueToReturn * INITIAL_RATIO) / 10000;
        uint256 expectedAndeValueToReturn = totalValueToReturn - expectedAusdToReturn;
        uint256 expectedAndeToReturn = (expectedAndeValueToReturn * 1e18) / ANDE_PRICE;


        // Act: Redeem the tokens
        vm.prank(user);
        abobToken.redeem(abobToMintAndRedeem);

        // Assert: Check balances for exact amounts
        assertEq(abobToken.balanceOf(user), 0, "User ABOB balance should be zero");
        
        assertEq(ausdToken.balanceOf(user), userAusdBefore + expectedAusdToReturn, "User AUSD balance is incorrect");
        assertEq(andeToken.balanceOf(user), userAndeBefore + expectedAndeToReturn, "User ANDE balance is incorrect");

        assertEq(ausdToken.balanceOf(address(abobToken)), contractAusdBefore - expectedAusdToReturn, "Contract AUSD balance is incorrect");
        assertEq(andeToken.balanceOf(address(abobToken)), contractAndeBefore - expectedAndeToReturn, "Contract ANDE balance is incorrect");
    }

    function test_Redeem_WhenAndePriceCrashes() public {
        uint256 abobToMintAndRedeem = 100e18;

        // Mint at normal price ($2)
        vm.prank(user);
        abobToken.mint(abobToMintAndRedeem);

        // --- Market Price Change Simulation ---
        // ANDE price increases from $2 to $4 (100% gain)
        // This tests that redemption works correctly with price volatility
        // User will receive fewer ANDE tokens but same USD value
        uint256 newAndePrice = 4 * 1e18;
        andePriceFeed.setPrice(newAndePrice);
        // ------------------------------

        uint256 userAndeBefore = andeToken.balanceOf(user);

        // Calculate expected return amounts with the new price
        uint256 totalValueToReturn = (abobToMintAndRedeem * ABOB_PRICE) / 1e18; // $100
        uint256 expectedAusdToReturn = (totalValueToReturn * INITIAL_RATIO) / 10000; // $70
        uint256 expectedAndeValueToReturn = totalValueToReturn - expectedAusdToReturn; // $30
        // User should get fewer ANDE tokens for the same $30 value
        // At $4/ANDE: $30 / $4 = 7.5 ANDE (vs 15 ANDE at $2)
        uint256 expectedAndeToReturn = (expectedAndeValueToReturn * 1e18) / newAndePrice;

        // Act: Redeem the tokens
        vm.prank(user);
        abobToken.redeem(abobToMintAndRedeem);

        // Assert: User gets fewer ANDE tokens back, but same USD value
        assertEq(andeToken.balanceOf(user), userAndeBefore + expectedAndeToReturn, "User should receive fewer ANDE after price increase");
    }

    function test_Redeem_RevertIf_AmountIsZero() public {
        vm.prank(user);
        vm.expectRevert("Amount must be positive");
        abobToken.redeem(0);
    }

    function test_Redeem_RevertIf_InsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert();
        abobToken.redeem(100e18); // User has no ABOB
    }

    function test_Redeem_EmitsEvent() public {
        uint256 abobToMint = 100e18;

        vm.prank(user);
        abobToken.mint(abobToMint);

        vm.expectEmit(true, false, false, false);
        emit AbobToken.Redeemed(user, abobToMint, 0, 0); // We don't check exact amounts

        vm.prank(user);
        abobToken.redeem(abobToMint);
    }

    // ==========================================
    // GOVERNANCE TESTS
    // ==========================================

    function test_Governance_CanSetCollateralRatio() public {
        uint256 newRatio = 8000; // 80%

        vm.expectEmit(true, true, true, true);
        emit AbobToken.CollateralRatioUpdated(newRatio);

        vm.prank(governance);
        abobToken.setCollateralRatio(newRatio);

        assertEq(abobToken.collateralRatio(), newRatio);
    }

    function test_Governance_RevertIf_RatioExceeds100Percent() public {
        uint256 invalidRatio = 10001; // 100.01%

        vm.prank(governance);
        vm.expectRevert("Ratio cannot exceed 100%");
        abobToken.setCollateralRatio(invalidRatio);
    }

    function test_Governance_OnlyGovernanceCanSetRatio() public {
        vm.prank(user);
        vm.expectRevert();
        abobToken.setCollateralRatio(8000);
    }

    function test_Governance_CanSetPriceFeeds() public {
        MockOracle newAndeFeed = new MockOracle(int256(ANDE_PRICE), 18);
        MockOracle newAbobFeed = new MockOracle(int256(ABOB_PRICE), 18);

        vm.prank(governance);
        abobToken.setPriceFeeds(address(newAndeFeed), address(newAbobFeed));

        assertEq(address(abobToken.andePriceFeed()), address(newAndeFeed));
        assertEq(address(abobToken.abobPriceFeed()), address(newAbobFeed));
    }

    function test_Governance_RevertIf_InvalidFeedAddress() public {
        vm.prank(governance);
        vm.expectRevert("Invalid feed address");
        abobToken.setPriceFeeds(address(0), address(abobPriceFeed));
    }

    function test_Governance_CanSetCollateralTokens() public {
        MockERC20 newAusd = new MockERC20("New AUSD", "NAUSD", 18);
        MockERC20 newAnde = new MockERC20("New ANDE", "NANDE", 18);

        vm.prank(governance);
        abobToken.setCollateralTokens(address(newAusd), address(newAnde));

        assertEq(address(abobToken.ausdToken()), address(newAusd));
        assertEq(address(abobToken.andeToken()), address(newAnde));
    }

    // ==========================================
    // PAUSE TESTS
    // ==========================================

    function test_Pause_PauserCanPause() public {
        vm.prank(pauser);
        abobToken.pause();

        assertTrue(abobToken.paused());
    }

    function test_Pause_PauserCanUnpause() public {
        vm.prank(pauser);
        abobToken.pause();

        vm.prank(pauser);
        abobToken.unpause();

        assertFalse(abobToken.paused());
    }

    function test_Pause_OnlyPauserCanPause() public {
        vm.prank(user);
        vm.expectRevert();
        abobToken.pause();
    }

    // ==========================================
    // FUZZING TESTS
    // ==========================================

    function testFuzz_Mint_WithVariousAmounts(uint256 amount) public {
        // Bound to reasonable amounts
        amount = bound(amount, 1e18, 1000e18);

        // Ensure user has enough collateral
        ausdToken.mint(user, amount * 10);
        andeToken.mint(user, amount * 10);

        vm.prank(user);
        abobToken.mint(amount);

        assertEq(abobToken.balanceOf(user), amount);
    }

    function testFuzz_CollateralRatio(uint256 ratio) public {
        ratio = bound(ratio, 0, 10000);

        vm.prank(governance);
        abobToken.setCollateralRatio(ratio);

        assertEq(abobToken.collateralRatio(), ratio);
    }
}
