// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../../src/dex/AndeSwapPair.sol";
import "../../src/dex/AndeSwapFactory.sol";
import "../../src/mocks/MockERC20.sol";

/**
 * @title TWAPOracleFix Test
 * @notice Tests for TWAP Oracle security fix
 * @dev Validates UQ112x112 encoding works correctly
 */
contract TWAPOracleFixTest is Test {
    AndeSwapFactory factory;
    AndeSwapPair pair;
    MockERC20 token0;
    MockERC20 token1;
    
    address alice = address(0x1);
    address bob = address(0x2);
    
    function setUp() public {
        factory = new AndeSwapFactory(address(this));
        
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);
        
        // Ensure token0 < token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = AndeSwapPair(pairAddress);
        
        // Mint tokens
        token0.mint(alice, 1000 ether);
        token1.mint(alice, 1000 ether);
    }
    
    function testTWAP_UQ112x112Encoding() public {
        vm.startPrank(alice);
        
        // Add initial liquidity
        token0.transfer(address(pair), 100 ether);
        token1.transfer(address(pair), 200 ether);
        pair.mint(alice);
        
        vm.stopPrank();
        
        // Record initial state
        uint256 price0Initial = pair.price0CumulativeLast();
        uint256 price1Initial = pair.price1CumulativeLast();
        
        // Wait 1 hour
        vm.warp(block.timestamp + 1 hours);
        
        // Trigger TWAP update with a swap
        vm.startPrank(alice);
        token0.transfer(address(pair), 1 ether);
        pair.swap(0, 1.98 ether, alice, "");
        vm.stopPrank();
        
        // Check TWAP accumulated
        uint256 price0After = pair.price0CumulativeLast();
        uint256 price1After = pair.price1CumulativeLast();
        
        // TWAP should have increased (not zero from division)
        assertGt(price0After, price0Initial, "Price0 cumulative should increase");
        assertGt(price1After, price1Initial, "Price1 cumulative should increase");
        
        // Calculate TWAP (price = delta / timeElapsed)
        uint256 timeElapsed = 1 hours;
        uint256 price0TWAP = (price0After - price0Initial) / timeElapsed;
        uint256 price1TWAP = (price1After - price1Initial) / timeElapsed;
        
        // Prices should be non-zero (fix prevents division by zero)
        assertGt(price0TWAP, 0, "Price0 TWAP should be > 0");
        assertGt(price1TWAP, 0, "Price1 TWAP should be > 0");
        
        // Price0 = reserve1 / reserve0 * 2^112
        // With reserves 200/100, price0 should be approximately 2 * 2^112
        uint256 expectedPrice0 = (uint256(200 ether) << 112) / 100 ether;
        uint256 tolerance = expectedPrice0 / 100; // 1% tolerance
        
        assertApproxEqAbs(
            price0TWAP, 
            expectedPrice0, 
            tolerance,
            "Price0 TWAP should match expected value"
        );
    }
    
    function testTWAP_NoDivisionByZero() public {
        // This would have caused division by zero before the fix
        
        vm.startPrank(alice);
        
        // Add liquidity with small amounts
        token0.transfer(address(pair), 1 wei);
        token1.transfer(address(pair), 1000 ether);
        pair.mint(alice);
        
        vm.stopPrank();
        
        // Wait and trigger update
        vm.warp(block.timestamp + 1);
        
        vm.startPrank(alice);
        token0.transfer(address(pair), 1 wei);
        
        // Should NOT revert (would have reverted with integer division)
        pair.swap(0, 1 ether, alice, "");
        vm.stopPrank();
        
        // TWAP should still accumulate correctly
        assertGt(pair.price0CumulativeLast(), 0, "TWAP should accumulate");
    }
    
    function testTWAP_Precision() public {
        vm.startPrank(alice);
        
        // Add liquidity: 100 token0, 300 token1
        // Expected price: token1/token0 = 3
        token0.transfer(address(pair), 100 ether);
        token1.transfer(address(pair), 300 ether);
        pair.mint(alice);
        
        vm.stopPrank();
        
        // Wait 10 seconds
        vm.warp(block.timestamp + 10);
        
        // Trigger update
        vm.startPrank(alice);
        token0.transfer(address(pair), 1 ether);
        pair.swap(0, 2.97 ether, alice, "");
        vm.stopPrank();
        
        // Calculate TWAP
        uint256 price0Cumulative = pair.price0CumulativeLast();
        uint256 twap = price0Cumulative / 10; // Divide by time elapsed
        
        // Expected: 3 * 2^112 (UQ112x112 encoding)
        uint256 expected = 3 << 112;
        
        // Should match with UQ112x112 precision
        assertApproxEqAbs(twap, expected, expected / 1000, "TWAP precision maintained");
    }
}
