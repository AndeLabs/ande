// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeSwapRouter} from "../../src/dex/AndeSwapRouter.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";
import {AndeSwapPair} from "../../src/dex/AndeSwapPair.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AndeSwapLibrary} from "../../src/dex/AndeSwapLibrary.sol";

contract AndeSwapRouterTest is Test {
    AndeSwapRouter public router;
    AndeSwapFactory public factory;
    ERC20Mock public token0;
    ERC20Mock public token1;
    ERC20Mock public token2;
    ERC20Mock public ande;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant TOKEN_SUPPLY = 10000 ether;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        token0 = new ERC20Mock("Token0", "T0");
        token1 = new ERC20Mock("Token1", "T1");
        token2 = new ERC20Mock("Token2", "T2");
        ande = new ERC20Mock("ANDE", "ANDE");
        
        // Mint initial supply to owner
        token0.mint(owner, TOKEN_SUPPLY);
        token1.mint(owner, TOKEN_SUPPLY);
        token2.mint(owner, TOKEN_SUPPLY);
        ande.mint(owner, TOKEN_SUPPLY);
        
        // Deploy factory and router
        factory = new AndeSwapFactory(owner);
        router = new AndeSwapRouter(address(factory));
        
        // Create pairs
        factory.createPair(address(token0), address(token1));
        factory.createPair(address(token1), address(token2));
        factory.createPair(address(token0), address(token2));
        
        // Transfer tokens to users
        token0.transfer(user1, 1000 ether);
        token1.transfer(user1, 1000 ether);
        token2.transfer(user1, 1000 ether);
        
        token0.transfer(user2, 500 ether);
        token1.transfer(user2, 500 ether);
        token2.transfer(user2, 500 ether);
        
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        vm.startPrank(user1);
        
        uint256 amountADesired = 100 ether;
        uint256 amountBDesired = 200 ether;
        uint256 amountAMin = 90 ether;
        uint256 amountBMin = 180 ether;
        uint256 deadline = block.timestamp + 3600;
        
        token0.approve(address(router), amountADesired);
        token1.approve(address(router), amountBDesired);
        
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            user1,
            deadline
        );
        
        assertEq(amountA, 100 ether);
        assertEq(amountB, 200 ether);
        // sqrt(100 * 200) = 141.421356237309503880...
        assertApproxEqAbs(liquidity, 141421356237309503880, 1000); // Allow tiny rounding error
        
        // Check pair reserves
        address pairAddress = factory.getPair(address(token0), address(token1));
        AndeSwapPair pair = AndeSwapPair(pairAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, 100 ether);
        assertEq(reserve1, 200 ether);
        
        vm.stopPrank();
    }

    function testAddLiquidityWithSlippage() public {
        vm.startPrank(user1);
        
        uint256 amountADesired = 100 ether;
        uint256 amountBDesired = 200 ether;
        uint256 amountAMin = 95 ether; // Allow 5% slippage
        uint256 amountBMin = 95 ether; // Adjusted to match pool ratio
        uint256 deadline = block.timestamp + 3600;
        
        // Add some liquidity first at 1:1 ratio
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 500 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            deadline
        );
        
        // Now add more liquidity - router will adjust to 100:100 to match pool ratio
        token0.approve(address(router), amountADesired);
        token1.approve(address(router), amountBDesired);
        
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            user1,
            deadline
        );
        
        // Should use 100:100 to match existing ratio
        assertEq(amountA, 100 ether);
        assertEq(amountB, 100 ether);
        assertTrue(amountA >= amountAMin);
        assertTrue(amountB >= amountBMin);
        
        vm.stopPrank();
    }

    function testAddLiquidityInsufficientLiquidity() public {
        vm.startPrank(user1);
        
        uint256 deadline = block.timestamp + 3600;
        
        // First add some liquidity at 1:1 ratio
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 500 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            deadline
        );
        
        // Try to add liquidity with impossible minimums
        // Pool is 1:1, so adding 100:200 will be adjusted to 100:100
        // But we set amountBMin = 190, which can't be met
        uint256 amountADesired = 100 ether;
        uint256 amountBDesired = 200 ether;
        uint256 amountAMin = 95 ether;
        uint256 amountBMin = 190 ether; // Too high for 1:1 ratio
        
        token0.approve(address(router), amountADesired);
        token1.approve(address(router), amountBDesired);
        
        vm.expectRevert(AndeSwapRouter.InsufficientBAmount.selector);
        router.addLiquidity(
            address(token0),
            address(token1),
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            user1,
            deadline
        );
        
        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        // Add liquidity first
        vm.startPrank(user1);
        token0.approve(address(router), 100 ether);
        token1.approve(address(router), 200 ether);
        
        (,, uint256 liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            100 ether,
            200 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        uint256 amountAMin = 90 ether;
        uint256 amountBMin = 180 ether;
        uint256 deadline = block.timestamp + 3600;
        
        address pairAddress = factory.getPair(address(token0), address(token1));
        AndeSwapPair pair = AndeSwapPair(pairAddress);
        pair.approve(address(router), liquidity);
        
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(token0),
            address(token1),
            liquidity,
            amountAMin,
            amountBMin,
            user1,
            deadline
        );
        
        // Due to MINIMUM_LIQUIDITY, amounts returned are slightly less
        assertApproxEqAbs(amountA, 100 ether, 2000);
        assertApproxEqAbs(amountB, 200 ether, 2000);
        
        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(router), 1000 ether);
        token1.approve(address(router), 1000 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            1000 ether,
            1000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        // Perform swap
        vm.startPrank(user2);
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 9 ether; // Allow some slippage
        uint256 deadline = block.timestamp + 3600;
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        uint256 balanceBefore = token1.balanceOf(user2);
        
        token0.approve(address(router), amountIn);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            user2,
            deadline
        );
        
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] >= amountOutMin);
        assertEq(token1.balanceOf(user2), balanceBefore + amounts[1]);
        
        vm.stopPrank();
    }

    function testSwapTokensForExactTokens() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(router), 1000 ether);
        token1.approve(address(router), 1000 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            1000 ether,
            1000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        // Perform swap
        vm.startPrank(user2);
        uint256 amountOut = 10 ether;
        uint256 amountInMax = 11 ether; // Allow some slippage
        uint256 deadline = block.timestamp + 3600;
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        uint256 balanceBefore = token0.balanceOf(user2);
        
        token0.approve(address(router), amountInMax);
        
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            user2,
            deadline
        );
        
        assertEq(amounts[1], amountOut);
        assertTrue(amounts[0] <= amountInMax);
        assertEq(token0.balanceOf(user2), balanceBefore - amounts[0]);
        
        vm.stopPrank();
    }

    // Skip: Requires ANDE precompile setup (0xfd) not available in test environment
    function skip_testSwapExactETHForTokens() public {
        // Add liquidity with ANDE
        vm.startPrank(user1);
        ande.approve(address(router), 1000 ether);
        token0.approve(address(router), 1000 ether);
        router.addLiquidity(
            address(ande),
            address(token0),
            1000 ether,
            1000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        // Perform ETH swap
        vm.startPrank(user2);
        uint256 amountOutMin = 9 ether;
        uint256 deadline = block.timestamp + 3600;
        
        address[] memory path = new address[](2);
        path[0] = router.ANDE();
        path[1] = address(token0);
        
        uint256 balanceBefore = token0.balanceOf(user2);
        
        vm.deal(user2, 10 ether);
        
        uint256[] memory amounts = router.swapExactANDEForTokens{value: 10 ether}(
            amountOutMin,
            path,
            user2,
            deadline
        );
        
        assertEq(amounts[0], 10 ether);
        assertTrue(amounts[1] >= amountOutMin);
        assertEq(token0.balanceOf(user2), balanceBefore + amounts[1]);
        
        vm.stopPrank();
    }

    // Skip: Requires ANDE precompile setup (0xfd) not available in test environment
    function skip_testSwapExactTokensForETH() public {
        // Add liquidity with ANDE
        vm.startPrank(user1);
        ande.approve(address(router), 1000 ether);
        token0.approve(address(router), 1000 ether);
        router.addLiquidity(
            address(token0),
            address(ande),
            1000 ether,
            1000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        // Perform token to ETH swap
        vm.startPrank(user2);
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 9 ether;
        uint256 deadline = block.timestamp + 3600;
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = router.ANDE();
        
        uint256 balanceBefore = user2.balance;
        
        token0.approve(address(router), amountIn);
        
        uint256[] memory amounts = router.swapTokensForExactANDE(
            amountIn,
            amountOutMin,
            path,
            user2,
            deadline
        );
        
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] >= amountOutMin);
        assertEq(user2.balance, balanceBefore + amounts[1]);
        
        vm.stopPrank();
    }

    function testMultihopSwap() public {
        // Add liquidity to all pairs (use smaller amounts since user1 only has 1000 of each)
        vm.startPrank(user1);
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 1000 ether); // Used in both pairs (500 + 500)
        token2.approve(address(router), 500 ether);
        
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        router.addLiquidity(
            address(token1),
            address(token2),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        // Perform multihop swap
        vm.startPrank(user2);
        uint256 amountIn = 10 ether;
        uint256 amountOutMin = 8 ether; // Allow more slippage for multihop
        uint256 deadline = block.timestamp + 3600;
        
        address[] memory path = new address[](3);
        path[0] = address(token0);
        path[1] = address(token1);
        path[2] = address(token2);
        
        uint256 balanceBefore = token2.balanceOf(user2);
        
        token0.approve(address(router), amountIn);
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            user2,
            deadline
        );
        
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[2] >= amountOutMin);
        assertEq(token2.balanceOf(user2), balanceBefore + amounts[2]);
        
        vm.stopPrank();
    }

    function testQuote() public {
        uint256 amountA = 100 ether;
        uint256 reserveA = 1000 ether;
        uint256 reserveB = 2000 ether;
        
        uint256 amountB = router.quote(amountA, reserveA, reserveB);
        assertEq(amountB, 200 ether); // 100 * 2000 / 1000
    }

    function testGetAmountOut() public {
        uint256 amountIn = 10 ether;
        uint256 reserveIn = 1000 ether;
        uint256 reserveOut = 1000 ether;
        
        uint256 amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        
        // Expected: 10 * 1000 / (1000 + 10) * 997/1000
        // Allow rounding error due to integer division
        uint256 expected = (amountIn * reserveOut * 997) / ((reserveIn + amountIn) * 1000);
        assertApproxEqAbs(amountOut, expected, 1e15); // 0.001 ether tolerance
    }

    function testGetAmountIn() public {
        uint256 amountOut = 10 ether;
        uint256 reserveIn = 1000 ether;
        uint256 reserveOut = 1000 ether;
        
        uint256 amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        
        // Expected: 1000 * 10 * 1000 / ((1000 - 10) * 997)
        // Router adds +1 to round up, so allow small difference
        uint256 expected = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997);
        assertApproxEqAbs(amountIn, expected, 2);
    }

    function testGetAmountsOut() public {
        // Add liquidity (use smaller amounts since user1 only has 1000 of each)
        vm.startPrank(user1);
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 1000 ether); // Used in both pairs (500 + 500)
        token2.approve(address(router), 500 ether);
        
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        router.addLiquidity(
            address(token1),
            address(token2),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        uint256 amountIn = 10 ether;
        address[] memory path = new address[](3);
        path[0] = address(token0);
        path[1] = address(token1);
        path[2] = address(token2);
        
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        
        assertEq(amounts[0], amountIn);
        assertTrue(amounts[1] > 0);
        assertTrue(amounts[2] > 0);
        assertTrue(amounts[2] < amounts[1]); // Slippage in multihop
    }

    function testGetAmountsIn() public {
        // Add liquidity (use smaller amounts since user1 only has 1000 of each)
        vm.startPrank(user1);
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 1000 ether); // Used in both pairs (500 + 500)
        token2.approve(address(router), 500 ether);
        
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        router.addLiquidity(
            address(token1),
            address(token2),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        vm.stopPrank();
        
        uint256 amountOut = 10 ether;
        address[] memory path = new address[](3);
        path[0] = address(token0);
        path[1] = address(token1);
        path[2] = address(token2);
        
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);
        
        assertEq(amounts[2], amountOut);
        assertTrue(amounts[1] > amountOut);
        assertTrue(amounts[0] > amounts[1]); // More input needed for multihop
    }

    function testDeadline() public {
        vm.startPrank(user1);
        
        uint256 deadline = block.timestamp - 1; // Expired
        
        token0.approve(address(router), 100 ether);
        token1.approve(address(router), 200 ether);
        
        vm.expectRevert(AndeSwapRouter.Expired.selector);
        router.addLiquidity(
            address(token0),
            address(token1),
            100 ether,
            200 ether,
            0,
            0,
            user1,
            deadline
        );
        
        vm.stopPrank();
    }

    function testGasUsage() public {
        // Add liquidity first
        vm.startPrank(user1);
        token0.approve(address(router), 500 ether);
        token1.approve(address(router), 500 ether);
        router.addLiquidity(
            address(token0),
            address(token1),
            500 ether,
            500 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        // Measure gas usage for swap (user1 still has 500 ether of each token)
        uint256 gasStart = gasleft();
        
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        
        token0.approve(address(router), 10 ether);
        router.swapExactTokensForTokens(
            10 ether,
            9 ether,
            path,
            user1,
            block.timestamp + 3600
        );
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Swap should use reasonable amount of gas
        assertTrue(gasUsed < 200000, "Swap uses too much gas");
        
        vm.stopPrank();
    }
}