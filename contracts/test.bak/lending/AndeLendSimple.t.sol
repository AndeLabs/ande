// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeLend} from "../../src/lending/AndeLend.sol";
import {AToken} from "../../src/lending/AToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockOracle} from "../mocks/MockOracle.sol";

contract AndeLendSimpleTest is Test {
    AndeLend public lendingPool;
    AToken public aUSDC;
    AToken public aANDE;
    ERC20Mock public usdc;
    ERC20Mock public ande;
    MockOracle public oracle;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens (18 decimals)
        usdc = new ERC20Mock("USD Coin", "USDC");
        ande = new ERC20Mock("ANDE Token", "ANDE");
        
        // Deploy oracle
        oracle = new MockOracle();
        oracle.setPrice(address(usdc), 1e18); // $1
        oracle.setPrice(address(ande), 1e18); // $1
        
        // Deploy lending pool
        lendingPool = new AndeLend(address(oracle));
        
        // Deploy aTokens
        aUSDC = new AToken("Ande USDC", "aUSDC", address(usdc), address(lendingPool));
        aANDE = new AToken("Ande ANDE", "aANDE", address(ande), address(lendingPool));
        
        // Create markets
        lendingPool.createMarket(address(usdc), address(aUSDC), 7500); // 75% LTV
        lendingPool.createMarket(address(ande), address(aANDE), 5000); // 50% LTV
        
        // Mint tokens
        usdc.mint(alice, 10000e18);
        ande.mint(alice, 10000e18);
        ande.mint(bob, 10000e18);
        
        vm.stopPrank();
    }
    
    function testSimpleBorrow() public {
        console.log("=== TEST SIMPLE BORROW ===");
        
        // Alice deposits 1000 USDC as collateral
        vm.startPrank(alice);
        usdc.approve(address(lendingPool), 1000e18);
        lendingPool.deposit(address(usdc), 1000e18, true);
        console.log("Alice deposited 1000 USDC");
        vm.stopPrank();
        
        // Check collateral value
        uint256 collateralValue = lendingPool.getUserCollateralValue(alice);
        console.log("Collateral value (with factor):", collateralValue);
        console.log("Expected: 750e18 (1000 * 0.75)");
        
        // Bob provides ANDE liquidity
        vm.startPrank(bob);
        ande.approve(address(lendingPool), 5000e18);
        lendingPool.deposit(address(ande), 5000e18, false);
        console.log("Bob provided 5000 ANDE liquidity");
        vm.stopPrank();
        
        // Alice tries to borrow 100 ANDE
        vm.startPrank(alice);
        console.log("\nAttempting to borrow 100 ANDE...");
        console.log("Collateral: 1000 USDC = $1000");
        console.log("Borrow power: $1000 * 0.75 = $750");
        console.log("Borrow amount: 100 ANDE = $100");
        console.log("Should work: $100 < $750");
        
        lendingPool.borrow(address(ande), 100e18);
        console.log("SUCCESS: Borrowed 100 ANDE");
        
        // Check health factor
        uint256 hf = lendingPool.getHealthFactor(alice);
        console.log("Health factor:", hf);
        console.log("Min required: 1e18");
        
        vm.stopPrank();
    }
}
