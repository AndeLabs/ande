// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {StabilityEngine} from "../../src/StabilityEngine.sol";
import {AbobToken} from "../../src/AbobToken.sol";
import {AusdToken} from "../../src/AusdToken.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {P2POracleV2} from "../../src/P2POracleV2.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StabilityEngineTest is Test {
    StabilityEngine public engine;
    AbobToken public abobToken;
    AusdToken public ausdToken;
    ANDEToken public andeToken;
    P2POracleV2 public p2pOracle;
    MockERC20 public usdcCollateral;
    MockOracle public usdcOracle;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        usdcCollateral = new MockERC20("Mock USDC", "USDC", 6);
        usdcOracle = new MockOracle();
        usdcOracle.setPrice(1 * 10**8);

        andeToken = ANDEToken(address(new ERC1967Proxy(address(new ANDEToken()), abi.encodeWithSelector(ANDEToken.initialize.selector, owner, owner))));
        p2pOracle = P2POracleV2(address(new ERC1967Proxy(address(new P2POracleV2()), abi.encodeWithSelector(P2POracleV2.initialize.selector, owner, address(andeToken), 1000 * 1e18, 3600))));
        ausdToken = AusdToken(address(new ERC1967Proxy(address(new AusdToken()), abi.encodeWithSelector(AusdToken.initialize.selector, owner))));
        abobToken = AbobToken(address(new ERC1967Proxy(address(new AbobToken()), abi.encodeWithSelector(AbobToken.initialize.selector, owner, owner))));
        engine = StabilityEngine(address(new ERC1967Proxy(address(new StabilityEngine()), abi.encodeWithSelector(StabilityEngine.initialize.selector, owner, address(abobToken), address(ausdToken), address(andeToken), address(p2pOracle)))));

        vm.startPrank(owner);
        abobToken.grantRole(abobToken.MINTER_ROLE(), address(engine));
        ausdToken.grantRole(ausdToken.COLLATERAL_MANAGER_ROLE(), owner);
        p2pOracle.grantRole(p2pOracle.FINALIZER_ROLE(), owner);
        andeToken.mint(owner, 1000 * 1e18);
        andeToken.approve(address(p2pOracle), 1000 * 1e18);
        p2pOracle.register();
        p2pOracle.reportPrice(2 * 1e18);
        vm.warp(block.timestamp + 3601);
        p2pOracle.finalizeCurrentEpoch();
        ausdToken.addCollateralType(address(usdcCollateral), 12000, address(usdcOracle));
        vm.stopPrank();

        usdcCollateral.mint(user, 240 * 10**6);
        vm.prank(owner);
        andeToken.mint(user, 100 * 1e18);

        vm.startPrank(user);
        usdcCollateral.approve(address(ausdToken), 240 * 10**6);
        ausdToken.depositAndMint(address(usdcCollateral), 240 * 10**6);
        vm.stopPrank();
    }

    function test_Mint_MintsAbobAndTakesCollateral() public {
        uint256 amountToMint = 100 * 1e18;
        uint256 expectedAusd = 80 * 1e18;
        uint256 expectedAnde = 10 * 1e18;

        uint256 initialAusd = ausdToken.balanceOf(user);
        uint256 initialAnde = andeToken.balanceOf(user);

        vm.startPrank(user);
        ausdToken.approve(address(engine), expectedAusd);
        andeToken.approve(address(engine), expectedAnde);
        engine.mint(amountToMint);
        vm.stopPrank();

        assertEq(abobToken.balanceOf(user), amountToMint);
        assertEq(ausdToken.balanceOf(user), initialAusd - expectedAusd);
        assertEq(andeToken.balanceOf(user), initialAnde - expectedAnde);
    }
}
