// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {P2POracle} from "../../src/P2POracle.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract P2POracleTest is Test {
    P2POracle public oracle;
    MockERC20 public andeToken;

    address public owner;
    address public finalizer;
    address public slasher;
    address public reporter1;
    address public reporter2;
    address public reporter3;

    uint256 public constant MIN_STAKE = 1000 * 1e18;
    uint256 public constant EPOCH_DURATION = 3600; // 1 hour

    function setUp() public {
        owner = makeAddr("owner");
        finalizer = makeAddr("finalizer");
        slasher = makeAddr("slasher");
        reporter1 = makeAddr("reporter1");
        reporter2 = makeAddr("reporter2");
        reporter3 = makeAddr("reporter3");

        andeToken = new MockERC20("ANDE Token", "ANDE", 18);

        P2POracle implementation = new P2POracle();
        bytes memory data = abi.encodeWithSelector(
            P2POracle.initialize.selector, owner, address(andeToken), MIN_STAKE, EPOCH_DURATION
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        oracle = P2POracle(address(proxy));

        vm.startPrank(owner);
        oracle.grantRole(oracle.FINALIZER_ROLE(), finalizer);
        oracle.grantRole(oracle.SLASHER_ROLE(), slasher);
        andeToken.mint(reporter1, MIN_STAKE * 10);
        andeToken.mint(reporter2, MIN_STAKE * 10);
        andeToken.mint(reporter3, MIN_STAKE * 10);
        vm.stopPrank();
    }

    modifier reporter1Registered() {
        vm.startPrank(reporter1);
        andeToken.approve(address(oracle), MIN_STAKE);
        oracle.register();
        vm.stopPrank();
        _;
    }

    function test_Deployment_CorrectInitialValues() public view {
        assertEq(address(oracle.andeToken()), address(andeToken));
        assertEq(oracle.minStake(), MIN_STAKE);
        assertEq(oracle.reportEpochDuration(), EPOCH_DURATION);
    }

    function test_Registration_CanRegister() public {
        vm.startPrank(reporter1);
        andeToken.approve(address(oracle), MIN_STAKE);
        oracle.register();
        vm.stopPrank();

        (bool isRegistered, uint256 stake,,) = oracle.reporters(reporter1);
        assertTrue(isRegistered);
        assertEq(stake, MIN_STAKE);
    }

    function test_Registration_Fail_NoAllowance() public {
        vm.prank(reporter1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(oracle), 0, MIN_STAKE)
        );
        oracle.register();
    }

    function test_Reporting_CanReportPrice() public reporter1Registered {
        uint256 price = 1.5 * 1e18;
        vm.prank(reporter1);
        oracle.reportPrice(price);
    }

    function test_Reporting_Fail_CannotReportTwice() public reporter1Registered {
        uint256 price = 1.5 * 1e18;
        vm.prank(reporter1);
        oracle.reportPrice(price);

        vm.prank(reporter1);
        vm.expectRevert(bytes("Already reported this epoch"));
        oracle.reportPrice(price);
    }

    function test_Finalization_CalculatesStakeWeightedMedian() public {
        vm.startPrank(reporter1);
        andeToken.approve(address(oracle), MIN_STAKE);
        oracle.register();
        vm.stopPrank();

        vm.startPrank(reporter2);
        andeToken.approve(address(oracle), MIN_STAKE);
        oracle.register();
        vm.stopPrank();

        vm.startPrank(reporter3);
        andeToken.approve(address(oracle), MIN_STAKE);
        oracle.register();
        vm.stopPrank();

        vm.prank(reporter2);
        oracle.reportPrice(200 * 1e16);
        vm.prank(reporter3);
        oracle.reportPrice(210 * 1e16);
        vm.prank(reporter1);
        oracle.reportPrice(190 * 1e16);

        uint256 epochToFinalize = oracle.currentEpoch();

        vm.warp(block.timestamp + EPOCH_DURATION + 1);
        vm.prank(finalizer);
        oracle.finalizeCurrentEpoch();

        assertEq(oracle.finalizedPrices(epochToFinalize), 200 * 1e16);
    }

    // ==================== Unregister Tests ====================

    function test_Unregister_Success() public reporter1Registered {
        uint256 balanceBefore = andeToken.balanceOf(reporter1);

        vm.prank(reporter1);
        oracle.unregister();

        (bool isRegistered, uint256 stake,,) = oracle.reporters(reporter1);
        assertFalse(isRegistered, "Reporter should be unregistered");
        assertEq(stake, 0, "Stake should be zero");
        assertEq(andeToken.balanceOf(reporter1), balanceBefore + MIN_STAKE, "Stake should be returned");
    }

    function test_Unregister_Fail_NotRegistered() public {
        vm.prank(reporter2); // An address that is not registered
        vm.expectRevert("Not a registered reporter");
        oracle.unregister();
    }

    // ==================== Slash Tests ====================

    function test_Slash_Success() public reporter1Registered {
        vm.prank(slasher);
        oracle.slash(reporter1);

        (bool isRegistered, uint256 stake,,) = oracle.reporters(reporter1);
        assertFalse(isRegistered, "Reporter should be unregistered after slash");
        assertEq(stake, 0, "Stake should be zero after slash");
    }

    function test_Slash_Fail_NotSlasher() public reporter1Registered {
        vm.startPrank(reporter2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", reporter2, oracle.SLASHER_ROLE()
            )
        );
        oracle.slash(reporter1);
        vm.stopPrank();
    }

    function test_Slash_Fail_NotRegistered() public {
        address nonExistentReporter = makeAddr("nonExistentReporter");
        vm.prank(slasher);
        vm.expectRevert("Not a registered reporter");
        oracle.slash(nonExistentReporter);
    }
}
