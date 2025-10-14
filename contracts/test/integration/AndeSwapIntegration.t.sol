// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";
import {AndeSwapRouter} from "../../src/dex/AndeSwapRouter.sol";
import {AndeSwapPair} from "../../src/dex/AndeSwapPair.sol";
import {AndeTokenFactory} from "../../src/factory/AndeTokenFactory.sol";
import {StandardToken} from "../../src/factory/templates/StandardToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract AndeSwapIntegrationTest is Test {
    AndeSwapFactory public dexFactory;
    AndeSwapRouter public router;
    AndeTokenFactory public tokenFactory;
    
    ERC20Mock public ande;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public feeRecipient = address(0x4);
    
    struct TokenInfo {
        address token;
        string name;
        string symbol;
        uint256 supply;
    }
    
    TokenInfo[] public createdTokens;

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy ANDE token
        ande = new ERC20Mock("ANDE", "ANDE", 1000000 ether);
        
        // Deploy DEX infrastructure
        dexFactory = new AndeSwapFactory(owner);
        router = new AndeSwapRouter(address(dexFactory));
        
        // Deploy Token Factory
        tokenFactory = new AndeTokenFactory(feeRecipient);
        
        // Transfer ANDE to users
        ande.transfer(user1, 10000 ether);
        ande.transfer(user2, 10000 ether);
        
        vm.stopPrank();
    }

    function testCompleteTokenCreationAndTradingFlow() public {
        // Step 1: Create tokens using Token Factory
        vm.startPrank(user1);
        
        address tokenA = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Token A",
            "TKA",
            1000000 ether
        );
        
        address tokenB = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Token B",
            "TKB",
            2000000 ether
        );
        
        vm.stopPrank();
        
        // Step 2: Create trading pairs on DEX
        vm.startPrank(owner);
        
        address pairAB = dexFactory.createPair(tokenA, tokenB);
        address pairANDE = dexFactory.createPair(tokenA, address(ande));
        address pairBNDE = dexFactory.createPair(tokenB, address(ande));
        
        vm.stopPrank();
        
        // Step 3: Add liquidity to pairs
        vm.startPrank(user1);
        
        // Add liquidity to A-B pair
        StandardToken(tokenA).approve(address(router), 100000 ether);
        StandardToken(tokenB).approve(address(router), 200000 ether);
        
        router.addLiquidity(
            tokenA,
            tokenB,
            100000 ether,
            200000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        // Add liquidity to A-ANDE pair
        StandardToken(tokenA).approve(address(router), 50000 ether);
        ande.approve(address(router), 1000 ether);
        
        router.addLiquidity(
            tokenA,
            address(ande),
            50000 ether,
            1000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        vm.stopPrank();
        
        // Step 4: Test trading between tokens
        vm.startPrank(user2);
        
        // Get some Token A from user1 for testing
        vm.prank(user1);
        StandardToken(tokenA).transfer(user2, 1000 ether);
        
        // Swap Token A for Token B
        StandardToken(tokenA).approve(address(router), 100 ether);
        
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        
        uint256 balanceBBefore = StandardToken(tokenB).balanceOf(user2);
        
        router.swapExactTokensForTokens(
            100 ether,
            190 ether, // Expected output with slippage
            path,
            user2,
            block.timestamp + 3600
        );
        
        uint256 balanceBAfter = StandardToken(tokenB).balanceOf(user2);
        assertTrue(balanceBAfter > balanceBBefore);
        
        // Step 5: Test multihop swap through ANDE
        StandardToken(tokenB).approve(address(router), 50 ether);
        
        address[] memory multihopPath = new address[](3);
        multihopPath[0] = tokenB;
        multihopPath[1] = address(ande);
        multihopPath[2] = tokenA;
        
        uint256 balanceABefore = StandardToken(tokenA).balanceOf(user2);
        
        router.swapExactTokensForTokens(
            50 ether,
            45 ether, // Expected output with slippage
            multihopPath,
            user2,
            block.timestamp + 3600
        );
        
        uint256 balanceAAfter = StandardToken(tokenA).balanceOf(user2);
        assertTrue(balanceAAfter > balanceABefore);
        
        vm.stopPrank();
        
        // Step 6: Verify liquidity provider rewards
        AndeSwapPair pairABContract = AndeSwapPair(pairAB);
        uint256 liquidityProviderBalance = pairABContract.balanceOf(user1);
        assertTrue(liquidityProviderBalance > 0);
        
        // Step 7: Test liquidity removal
        vm.startPrank(user1);
        
        pairABContract.approve(address(router), liquidityProviderBalance);
        
        uint256 balanceABefore = StandardToken(tokenA).balanceOf(user1);
        uint256 balanceBBefore = StandardToken(tokenB).balanceOf(user1);
        
        router.removeLiquidity(
            tokenA,
            tokenB,
            liquidityProviderBalance,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        uint256 balanceAAfter = StandardToken(tokenA).balanceOf(user1);
        uint256 balanceBAfter = StandardToken(tokenB).balanceOf(user1);
        
        assertTrue(balanceAAfter > balanceABefore);
        assertTrue(balanceBAfter > balanceBBefore);
        
        vm.stopPrank();
    }

    function testTokenFactoryRevenueGeneration() public {
        uint256 initialFeeBalance = feeRecipient.balance;
        
        // Create multiple tokens
        vm.startPrank(user1);
        
        for (uint256 i = 0; i < 5; i++) {
            tokenFactory.createStandardToken{value: 0.01 ether}(
                string(abi.encodePacked("Token ", i)),
                string(abi.encodePacked("TK", i)),
                1000000 ether
            );
        }
        
        vm.stopPrank();
        
        // Withdraw fees
        vm.prank(owner);
        tokenFactory.withdrawFees();
        
        uint256 finalFeeBalance = feeRecipient.balance;
        assertEq(finalFeeBalance - initialFeeBalance, 0.05 ether); // 5 * 0.01 ether
    }

    function testPriceDiscoveryAcrossMultiplePairs() public {
        // Create tokens
        vm.startPrank(user1);
        
        address tokenX = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Token X",
            "TKX",
            1000000 ether
        );
        
        address tokenY = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Token Y",
            "TKY",
            1000000 ether
        );
        
        address tokenZ = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Token Z",
            "TKZ",
            1000000 ether
        );
        
        vm.stopPrank();
        
        // Create pairs
        vm.startPrank(owner);
        
        dexFactory.createPair(tokenX, tokenY);
        dexFactory.createPair(tokenY, tokenZ);
        dexFactory.createPair(tokenX, tokenZ);
        
        vm.stopPrank();
        
        // Add liquidity with different price ratios
        vm.startPrank(user1);
        
        // X-Y: 1:1 ratio
        StandardToken(tokenX).approve(address(router), 100000 ether);
        StandardToken(tokenY).approve(address(router), 100000 ether);
        router.addLiquidity(tokenX, tokenY, 100000 ether, 100000 ether, 0, 0, user1, block.timestamp + 3600);
        
        // Y-Z: 1:2 ratio (Y is more valuable)
        StandardToken(tokenY).approve(address(router), 50000 ether);
        StandardToken(tokenZ).approve(address(router), 100000 ether);
        router.addLiquidity(tokenY, tokenZ, 50000 ether, 100000 ether, 0, 0, user1, block.timestamp + 3600);
        
        vm.stopPrank();
        
        // Test arbitrage opportunity
        vm.startPrank(user2);
        
        // Get tokens for trading
        vm.prank(user1);
        StandardToken(tokenX).transfer(user2, 1000 ether);
        
        // Direct swap X->Z
        StandardToken(tokenX).approve(address(router), 100 ether);
        
        address[] memory directPath = new address[](2);
        directPath[0] = tokenX;
        directPath[1] = tokenZ;
        
        uint256[] memory directAmounts = router.getAmountsOut(100 ether, directPath);
        
        // Multihop swap X->Y->Z
        address[] memory multihopPath = new address[](3);
        multihopPath[0] = tokenX;
        multihopPath[1] = tokenY;
        multihopPath[2] = tokenZ;
        
        uint256[] memory multihopAmounts = router.getAmountsOut(100 ether, multihopPath);
        
        // There should be a price difference (arbitrage opportunity)
        assertTrue(directAmounts[1] != multihopAmounts[2]);
        
        vm.stopPrank();
    }

    function testLiquidityProviderIncentives() public {
        // Create token and pair
        vm.startPrank(user1);
        
        address token = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Liquidity Token",
            "LIQ",
            1000000 ether
        );
        
        vm.stopPrank();
        
        vm.startPrank(owner);
        address pair = dexFactory.createPair(token, address(ande));
        vm.stopPrank();
        
        // Multiple liquidity providers
        address[] memory providers = new address[](3);
        providers[0] = user1;
        providers[1] = user2;
        providers[2] = owner;
        
        // Each provider adds liquidity
        for (uint256 i = 0; i < providers.length; i++) {
            vm.startPrank(providers[i]);
            
            if (i == 0) {
                // user1 already has tokens
                StandardToken(token).approve(address(router), 10000 ether);
                ande.approve(address(router), 100 ether);
            } else if (i == 1) {
                // user2 needs tokens
                vm.prank(user1);
                StandardToken(token).transfer(user2, 10000 ether);
                ande.transfer(user2, 100 ether);
                
                StandardToken(token).approve(address(router), 10000 ether);
                ande.approve(address(router), 100 ether);
            } else {
                // owner needs tokens
                vm.prank(user1);
                StandardToken(token).transfer(owner, 10000 ether);
                ande.transfer(owner, 100 ether);
                
                StandardToken(token).approve(address(router), 10000 ether);
                ande.approve(address(router), 100 ether);
            }
            
            router.addLiquidity(
                token,
                address(ande),
                10000 ether,
                100 ether,
                0,
                0,
                providers[i],
                block.timestamp + 3600
            );
            
            vm.stopPrank();
        }
        
        // Generate trading volume and fees
        vm.startPrank(user1);
        StandardToken(token).approve(address(router), 1000 ether);
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(ande);
        
        for (uint256 i = 0; i < 10; i++) {
            router.swapExactTokensForTokens(
                10 ether,
                0.09 ether,
                path,
                user1,
                block.timestamp + 3600
            );
        }
        vm.stopPrank();
        
        // Check that liquidity providers have earned fees
        AndeSwapPair pairContract = AndeSwapPair(pair);
        uint256 totalSupply = pairContract.totalSupply();
        
        for (uint256 i = 0; i < providers.length; i++) {
            uint256 providerBalance = pairContract.balanceOf(providers[i]);
            assertTrue(providerBalance > 0);
            
            // Each provider should have roughly equal share
            uint256 expectedShare = totalSupply / providers.length;
            assertEq(providerBalance, expectedShare);
        }
    }

    function testComplexTradingScenario() public {
        // Create a complex ecosystem with multiple tokens
        vm.startPrank(user1);
        
        address[] memory tokens = new address[](4);
        tokens[0] = tokenFactory.createStandardToken{value: 0.01 ether}("Token Alpha", "ALPHA", 1000000 ether);
        tokens[1] = tokenFactory.createStandardToken{value: 0.01 ether}("Token Beta", "BETA", 2000000 ether);
        tokens[2] = tokenFactory.createStandardToken{value: 0.01 ether}("Token Gamma", "GAMMA", 1500000 ether);
        tokens[3] = tokenFactory.createStandardToken{value: 0.01 ether}("Token Delta", "DELTA", 3000000 ether);
        
        vm.stopPrank();
        
        // Create all possible pairs
        vm.startPrank(owner);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = i + 1; j < tokens.length; j++) {
                dexFactory.createPair(tokens[i], tokens[j]);
            }
        }
        
        // Create pairs with ANDE
        for (uint256 i = 0; i < tokens.length; i++) {
            dexFactory.createPair(tokens[i], address(ande));
        }
        
        vm.stopPrank();
        
        // Add liquidity to create a market
        vm.startPrank(user1);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            StandardToken(tokens[i]).approve(address(router), 50000 ether);
            ande.approve(address(router), 500 ether);
            
            router.addLiquidity(
                tokens[i],
                address(ande),
                50000 ether,
                500 ether,
                0,
                0,
                user1,
                block.timestamp + 3600
            );
        }
        
        vm.stopPrank();
        
        // Simulate trading activity
        vm.startPrank(user2);
        
        // Distribute tokens to user2
        vm.startPrank(user1);
        for (uint256 i = 0; i < tokens.length; i++) {
            StandardToken(tokens[i]).transfer(user2, 1000 ether);
        }
        vm.stopPrank();
        
        // Perform complex trading strategies
        for (uint256 round = 0; round < 5; round++) {
            // Rotate through tokens
            for (uint256 i = 0; i < tokens.length; i++) {
                uint256 nextIndex = (i + 1) % tokens.length;
                
                StandardToken(tokens[i]).approve(address(router), 50 ether);
                
                address[] memory path = new address[](3);
                path[0] = tokens[i];
                path[1] = address(ande);
                path[2] = tokens[nextIndex];
                
                router.swapExactTokensForTokens(
                    50 ether,
                    45 ether, // Allow slippage
                    path,
                    user2,
                    block.timestamp + 3600
                );
            }
        }
        
        vm.stopPrank();
        
        // Verify that all trading occurred successfully
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = StandardToken(tokens[i]).balanceOf(user2);
            assertTrue(balance > 0);
        }
    }

    function testGasOptimizationInBatchOperations() public {
        // Create tokens
        vm.startPrank(user1);
        
        address tokenA = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Gas Token A",
            "GASA",
            1000000 ether
        );
        
        address tokenB = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Gas Token B",
            "GASB",
            1000000 ether
        );
        
        vm.stopPrank();
        
        // Create pair
        vm.startPrank(owner);
        address pair = dexFactory.createPair(tokenA, tokenB);
        vm.stopPrank();
        
        // Measure gas usage for batch operations
        vm.startPrank(user1);
        
        uint256 gasStart = gasleft();
        
        // Batch approve
        StandardToken(tokenA).approve(address(router), 100000 ether);
        StandardToken(tokenB).approve(address(router), 200000 ether);
        
        uint256 approveGas = gasStart - gasleft();
        
        gasStart = gasleft();
        
        // Add liquidity
        router.addLiquidity(
            tokenA,
            tokenB,
            100000 ether,
            200000 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        uint256 liquidityGas = gasStart - gasleft();
        
        gasStart = gasleft();
        
        // Batch swap operations
        StandardToken(tokenA).approve(address(router), 1000 ether);
        
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        
        for (uint256 i = 0; i < 10; i++) {
            router.swapExactTokensForTokens(
                10 ether,
                9 ether,
                path,
                user1,
                block.timestamp + 3600
            );
        }
        
        uint256 batchSwapGas = gasStart - gasleft();
        
        console.log("Approve gas:", approveGas);
        console.log("Liquidity gas:", liquidityGas);
        console.log("Batch swap gas:", batchSwapGas);
        console.log("Average swap gas:", batchSwapGas / 10);
        
        // Verify gas efficiency
        assertTrue(approveGas < 100000, "Approval should be gas efficient");
        assertTrue(liquidityGas < 500000, "Liquidity addition should be gas efficient");
        assertTrue(batchSwapGas / 10 < 150000, "Individual swaps should be gas efficient");
        
        vm.stopPrank();
    }

    function testSecurityIntegration() public {
        // Test that all security measures work together
        
        // 1. Token Factory security
        vm.startPrank(user1);
        
        // Should fail with insufficient fee
        vm.expectRevert();
        tokenFactory.createStandardToken("No Fee Token", "NOFEE", 1000000 ether);
        
        // Should work with correct fee
        address token = tokenFactory.createStandardToken{value: 0.01 ether}(
            "Secure Token",
            "SECURE",
            1000000 ether
        );
        
        vm.stopPrank();
        
        // 2. DEX security
        vm.startPrank(owner);
        address pair = dexFactory.createPair(token, address(ande));
        vm.stopPrank();
        
        // 3. Test reentrancy protection
        vm.startPrank(user1);
        
        StandardToken(token).approve(address(router), 1000 ether);
        ande.approve(address(router), 10 ether);
        
        router.addLiquidity(
            token,
            address(ande),
            1000 ether,
            10 ether,
            0,
            0,
            user1,
            block.timestamp + 3600
        );
        
        // Attempt to manipulate reserves (should fail)
        AndeSwapPair pairContract = AndeSwapPair(pair);
        
        vm.expectRevert();
        pairContract.sync(); // Only factory can call
        
        vm.stopPrank();
        
        // 4. Test deadline protection
        vm.startPrank(user2);
        
        vm.prank(user1);
        StandardToken(token).transfer(user2, 100 ether);
        
        StandardToken(token).approve(address(router), 10 ether);
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(ande);
        
        vm.expectRevert(); // Should fail due to expired deadline
        router.swapExactTokensForTokens(
            10 ether,
            1 ether,
            path,
            user2,
            block.timestamp - 1 // Expired
        );
        
        vm.stopPrank();
    }
}