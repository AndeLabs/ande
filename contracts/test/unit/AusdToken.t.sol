// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {AusdToken} from "../../src/AusdToken.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract AusdTokenTest is Test {
    AusdToken public ausdToken;
    MockERC20 public usdcCollateral;
    MockOracle public usdcOracle;

    address public owner;
    address public user;
    address public collateralManager;
    address public pauser;

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        collateralManager = makeAddr("collateralManager");
        pauser = makeAddr("pauser");

        usdcCollateral = new MockERC20("Mock USDC", "USDC", 6);
        usdcOracle = new MockOracle();
        usdcOracle.setPrice(1 * 10**8);

        AusdToken implementation = new AusdToken();
        bytes memory data = abi.encodeWithSelector(AusdToken.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        ausdToken = AusdToken(address(proxy));

        vm.startPrank(owner);
        ausdToken.grantRole(COLLATERAL_MANAGER_ROLE, collateralManager);
        ausdToken.grantRole(PAUSER_ROLE, pauser);
        vm.stopPrank();

        usdcCollateral.mint(user, 10_000 * 10**6);
    }

    modifier givenUsdcIsCollateral() {
        vm.prank(collateralManager);
        ausdToken.addCollateralType(address(usdcCollateral), 12000, address(usdcOracle)); // 120%
        _;
    }

    function test_Deployment_HasCorrectNameAndSymbol() public view {
        assertEq(ausdToken.name(), "Ande USD");
        assertEq(ausdToken.symbol(), "AUSD");
    }

    function test_ManagerCanAddCollateral() public {
        vm.prank(collateralManager);
        ausdToken.addCollateralType(address(usdcCollateral), 12000, address(usdcOracle));
        (bool isSupported,,,) = ausdToken.collateralTypes(address(usdcCollateral));
        assertTrue(isSupported);
    }

    function test_Core_DepositAndMint() public givenUsdcIsCollateral {
        uint256 depositAmount = 120 * 10**6; // 120 USDC
        uint256 expectedAusd = 100 * 1e18;

        vm.startPrank(user);
        usdcCollateral.approve(address(ausdToken), depositAmount);
        ausdToken.depositAndMint(address(usdcCollateral), depositAmount);
        vm.stopPrank();

        assertEq(ausdToken.balanceOf(user), expectedAusd);
    }

    function test_Core_BurnAndWithdraw() public givenUsdcIsCollateral {
        uint256 depositAmount = 120 * 10**6;
        uint256 ausdToMint = 100 * 1e18;

        vm.startPrank(user);
        usdcCollateral.approve(address(ausdToken), depositAmount);
        ausdToken.depositAndMint(address(usdcCollateral), depositAmount);
        vm.stopPrank();

        uint256 userInitialUsdc = usdcCollateral.balanceOf(user);
        
        vm.startPrank(user);
        ausdToken.burnAndWithdraw(address(usdcCollateral), ausdToMint);
        vm.stopPrank();

        assertEq(ausdToken.balanceOf(user), 0);
        assertEq(usdcCollateral.balanceOf(user), userInitialUsdc + depositAmount);
    }
}
