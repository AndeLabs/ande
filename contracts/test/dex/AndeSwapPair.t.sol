// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeSwapPair} from "../../src/dex/AndeSwapPair.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";

contract AndeSwapPairTest is Test {
    AndeSwapPair public pair;
    ERC20Mock public token0;
    ERC20Mock public token1;
    ERC20Mock public ande;
    AndeSwapFactory public factory;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant TOKEN0_SUPPLY = 1000 ether;
    uint256 public constant TOKEN1_SUPPLY = 2000 ether;
    uint256 public constant ANDE_SUPPLY = 1000000 ether;
    
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        token0 = new ERC20Mock("Token0", "T0", TOKEN0_SUPPLY);
        token1 = new ERC20Mock("Token1", "T1", TOKEN1_SUPPLY);
        ande = new ERC20Mock("ANDE", "ANDE", ANDE_SUPPLY);
        
        // Deploy factory
        factory = new AndeSwapFactory(owner);
        
        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = AndeSwapPair(pairAddress);
        
        // Transfer tokens to users
        token0.transfer(user1, 100 ether);
        token1.transfer(user1, 200 ether);
        token0.transfer(user2, 50 ether);
        token1.transfer(user2, 100 ether);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(pair.factory(), address(factory));
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
        assertEq(pair.reserve0(), 0);
        assertEq(pair.reserve1(), 0);
        assertEq(pair.totalSupply(), 0);
    }

    function testMintFirstLiquidity() public {
        vm.startPrank(user1);
        
        uint256 amount0Desired = 1 ether;
        uint256 amount1Desired = 2 ether;
        
        token0.approve(address(pair), amount0Desired);
        token1.approve(address(pair), amount1Desired);
        
        vm.expectEmit(true, true, true, true);
        emit Mint(user1, amount0Desired, amount1Desired);
        
        pair.mint(user1);
        
        assertEq(pair.balanceOf(user1), 1 ether);
        assertEq(pair.reserve0(), amount0Desired);
        assertEq(pair.reserve1(), amount1Desired);
        assertEq(pair.totalSupply(), 1 ether);
        
        vm.stopPrank();
    }

    function testMintAdditionalLiquidity() public {
        // Add initial liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 1 ether);
        token1.approve(address(pair), 2 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Add more liquidity
        vm.startPrank(user2);
        uint256 amount0Desired = 0.5 ether;
        uint256 amount1Desired = 1 ether;
        
        token0.approve(address(pair), amount0Desired);
        token1.approve(address(pair), amount1Desired);
        
        uint256 expectedLiquidity = 0.5 ether; // Half of initial liquidity
        
        vm.expectEmit(true, true, true, true);
        emit Mint(user2, amount0Desired, amount1Desired);
        
        pair.mint(user2);
        
        assertEq(pair.balanceOf(user2), expectedLiquidity);
        assertEq(pair.reserve0(), 1.5 ether);
        assertEq(pair.reserve1(), 3 ether);
        assertEq(pair.totalSupply(), 1.5 ether);
        
        vm.stopPrank();
    }

    function testBurnLiquidity() public {
        // Add liquidity first
        vm.startPrank(user1);
        token0.approve(address(pair), 1 ether);
        token1.approve(address(pair), 2 ether);
        pair.mint(user1);
        
        uint256 liquidityToBurn = 0.5 ether;
        
        vm.expectEmit(true, true, true, true);
        emit Burn(user1, 0.5 ether, 1 ether, user1);
        
        pair.burn(user1);
        
        assertEq(pair.balanceOf(user1), 0.5 ether);
        assertEq(pair.reserve0(), 0.5 ether);
        assertEq(pair.reserve1(), 1 ether);
        assertEq(pair.totalSupply(), 0.5 ether);
        
        // Check user received tokens
        assertEq(token0.balanceOf(user1), 99.5 ether);
        assertEq(token1.balanceOf(user1), 199 ether);
        
        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 10 ether);
        token1.approve(address(pair), 20 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Perform swap
        vm.startPrank(user2);
        uint256 amountIn = 1 ether;
        uint256 amountOutMin = 1.8 ether; // Expect some slippage
        
        token0.approve(address(pair), amountIn);
        
        uint256 balanceBefore = token1.balanceOf(user2);
        
        vm.expectEmit(true, true, true, true);
        emit Swap(user2, amountIn, 0, 0, 1.8 ether, user2);
        
        pair.swap(0, 1.8 ether, user2, "");
        
        assertEq(token1.balanceOf(user2), balanceBefore + 1.8 ether);
        assertEq(pair.reserve0(), 11 ether);
        assertEq(pair.reserve1(), 18.2 ether);
        
        vm.stopPrank();
    }

    function testSwapWithInsufficientLiquidity() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 1 ether);
        token1.approve(address(pair), 2 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Try to swap more than available
        vm.startPrank(user2);
        token0.approve(address(pair), 2 ether);
        
        vm.expectRevert(AndeSwapPair.InsufficientLiquidity.selector);
        pair.swap(0, 3 ether, user2, "");
        
        vm.stopPrank();
    }

    function testSwapWithInsufficientOutputAmount() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 10 ether);
        token1.approve(address(pair), 20 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token0.approve(address(pair), 1 ether);
        
        // Ask for too much output
        vm.expectRevert(AndeSwapPair.InsufficientOutputAmount.selector);
        pair.swap(0, 25 ether, user2, "");
        
        vm.stopPrank();
    }

    function testGetReserves() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 5 ether);
        token1.approve(address(pair), 10 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        (uint112 reserve0, uint112 reserve1) = pair.getReserves();
        assertEq(reserve0, 5 ether);
        assertEq(reserve1, 10 ether);
    }

    function testPriceImpactCalculation() public {
        // Add initial liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 100 ether);
        token1.approve(address(pair), 100 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Small swap should have minimal price impact
        vm.startPrank(user2);
        token0.approve(address(pair), 1 ether);
        
        uint256 expectedOut = pair.getAmountOut(1 ether, 100 ether, 100 ether);
        
        // For small swaps, price impact should be minimal
        assertTrue(expectedOut > 0.98 ether, "Price impact too high for small swap");
        
        vm.stopPrank();
    }

    function testKInvariant() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 100 ether);
        token1.approve(address(pair), 100 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        uint256 kBefore = pair.reserve0() * pair.reserve1();
        
        // Perform swap
        vm.startPrank(user2);
        token0.approve(address(pair), 1 ether);
        pair.swap(0, 0.99 ether, user2, ""); // Approximate output
        vm.stopPrank();
        
        uint256 kAfter = pair.reserve0() * pair.reserve1();
        
        // K should increase slightly due to fees (0.3%)
        assertTrue(kAfter > kBefore, "K invariant violated");
        
        // Fee should be 0.3% of input amount
        uint256 expectedFee = (1 ether * 3) / 1000;
        uint256 actualFee = kAfter - kBefore;
        assertEq(actualFee, expectedFee * 100, "Fee calculation incorrect"); // Scaled by reserve1
    }

    function testEmergencyFunctions() public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 10 ether);
        token1.approve(address(pair), 20 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Test sync function
        vm.startPrank(owner);
        pair.sync();
        
        (uint112 reserve0, uint112 reserve1) = pair.getReserves();
        assertEq(reserve0, 10 ether);
        assertEq(reserve1, 20 ether);
        
        vm.stopPrank();
    }

    function testPermit() public {
        // Add liquidity first
        vm.startPrank(user1);
        token0.approve(address(pair), 1 ether);
        token1.approve(address(pair), 2 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Test permit functionality
        uint256 privateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        address spender = address(0x4);
        uint256 value = 0.5 ether;
        uint256 deadline = block.timestamp + 3600;
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, keccak256(
            abi.encodePacked(
                "\x19\x01",
                pair.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(pair.PERMIT_TYPEHASH(), user1, spender, value, deadline))
            )
        ));
        
        vm.prank(user1);
        pair.permit(user1, spender, value, deadline, v, r, s);
        
        assertEq(pair.allowance(user1, spender), value);
    }

    function testFuzzSwap(uint256 amountIn) public {
        // Add liquidity
        vm.startPrank(user1);
        token0.approve(address(pair), 1000 ether);
        token1.approve(address(pair), 1000 ether);
        pair.mint(user1);
        vm.stopPrank();
        
        // Bound the input to reasonable values
        vm.assume(amountIn > 0 && amountIn <= 100 ether);
        
        vm.startPrank(user2);
        token0.mint(user2, amountIn);
        token0.approve(address(pair), amountIn);
        
        uint256 amountOut = pair.getAmountOut(amountIn, pair.reserve0(), pair.reserve1());
        
        if (amountOut > 0 && amountOut < pair.reserve1()) {
            pair.swap(0, amountOut, user2, "");
            
            // Verify K invariant increased (fees collected)
            uint256 kAfter = pair.reserve0() * pair.reserve1();
            uint256 kBefore = 1000 ether * 1000 ether;
            assertTrue(kAfter >= kBefore, "K invariant violated");
        }
        
        vm.stopPrank();
    }
}