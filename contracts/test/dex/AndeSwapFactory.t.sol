// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";
import {AndeSwapPair} from "../../src/dex/AndeSwapPair.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract AndeSwapFactoryTest is Test {
    AndeSwapFactory public factory;
    ERC20Mock public token0;
    ERC20Mock public token1;
    ERC20Mock public token2;
    ERC20Mock public ande;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public feeTo = address(0x3);
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeToUpdated(address indexed newFeeTo);
    event FeeToSetterUpdated(address indexed newFeeToSetter);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy tokens
        token0 = new ERC20Mock("Token0", "T0");
        token1 = new ERC20Mock("Token1", "T1");
        token2 = new ERC20Mock("Token2", "T2");
        ande = new ERC20Mock("ANDE", "ANDE");
        
        // Mint initial supply
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);
        token2.mint(address(this), 1000 ether);
        ande.mint(address(this), 1000000 ether);
        
        // Deploy factory
        factory = new AndeSwapFactory(owner);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(factory.feeToSetter(), owner);
        assertEq(factory.feeTo(), address(0));
        assertEq(factory.allPairsLength(), 0);
    }

    function testCreatePair() public {
        vm.expectEmit(true, true, true, true);
        emit PairCreated(address(token0), address(token1), address(0), 0);
        
        address pairAddress = factory.createPair(address(token0), address(token1));
        
        assertTrue(pairAddress != address(0), "Pair address should not be zero");
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.getPair(address(token0), address(token1)), pairAddress);
        assertEq(factory.getPair(address(token1), address(token0)), pairAddress);
        
        // Verify pair is deployed correctly
        AndeSwapPair pair = AndeSwapPair(pairAddress);
        assertEq(pair.factory(), address(factory));
        assertEq(pair.token0(), address(token0));
        assertEq(pair.token1(), address(token1));
    }

    function testCreatePairWithSameTokens() public {
        vm.expectRevert(AndeSwapFactory.IdenticalAddresses.selector);
        factory.createPair(address(token0), address(token0));
    }

    function testCreatePairWithZeroAddress() public {
        vm.expectRevert(AndeSwapFactory.ZeroAddress.selector);
        factory.createPair(address(0), address(token1));
        
        vm.expectRevert(AndeSwapFactory.ZeroAddress.selector);
        factory.createPair(address(token0), address(0));
    }

    function testCreatePairAlreadyExists() public {
        // Create first pair
        factory.createPair(address(token0), address(token1));
        
        // Try to create same pair again
        vm.expectRevert(AndeSwapFactory.PairExists.selector);
        factory.createPair(address(token0), address(token1));
        
        // Try reverse order
        vm.expectRevert(AndeSwapFactory.PairExists.selector);
        factory.createPair(address(token1), address(token0));
    }

    function testCreatePairWithSortedTokens() public {
        // Test with token0 < token1 (address comparison)
        address pairAddress1 = factory.createPair(address(token0), address(token1));
        address pairAddress2 = factory.createPair(address(token1), address(token2));
        
        assertEq(pairAddress1, factory.getPair(address(token0), address(token1)));
        assertEq(pairAddress1, factory.getPair(address(token1), address(token0)));
        
        assertEq(pairAddress2, factory.getPair(address(token1), address(token2)));
        assertEq(pairAddress2, factory.getPair(address(token2), address(token1)));
        
        // Verify pairs are different
        assertTrue(pairAddress1 != pairAddress2);
        
        // Verify total pairs count
        assertEq(factory.allPairsLength(), 2);
        assertEq(factory.allPairs(0), pairAddress1);
        assertEq(factory.allPairs(1), pairAddress2);
    }

    function testSetFeeTo() public {
        vm.expectEmit(true, true, true, true);
        emit FeeToUpdated(feeTo);
        
        vm.prank(owner);
        factory.setFeeTo(feeTo);
        
        assertEq(factory.feeTo(), feeTo);
    }

    function testSetFeeToUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        factory.setFeeTo(feeTo);
    }

    function testSetFeeToSetter() public {
        address newFeeToSetter = address(0x4);
        
        vm.expectEmit(true, true, true, true);
        emit FeeToSetterUpdated(newFeeToSetter);
        
        vm.prank(owner);
        factory.setFeeToSetter(newFeeToSetter);
        
        assertEq(factory.feeToSetter(), newFeeToSetter);
        
        // Test that old owner can no longer set feeTo
        vm.prank(owner);
        vm.expectRevert();
        factory.setFeeTo(address(0x5));
        
        // Test that new owner can set feeTo
        vm.prank(newFeeToSetter);
        factory.setFeeTo(address(0x5));
        assertEq(factory.feeTo(), address(0x5));
    }

    function testSetFeeToSetterUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        factory.setFeeToSetter(user);
    }

    function testCreatePairWithFeeTo() public {
        // Set feeTo address
        vm.prank(owner);
        factory.setFeeTo(feeTo);
        
        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        
        // Verify feeTo is set in the pair
        AndeSwapPair pair = AndeSwapPair(pairAddress);
        // This would be tested when liquidity is added and fees are collected
    }

    function testGetPair() public {
        // Before creating pair
        assertEq(factory.getPair(address(token0), address(token1)), address(0));
        assertEq(factory.getPair(address(token1), address(token0)), address(0));
        
        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        
        // After creating pair
        assertEq(factory.getPair(address(token0), address(token1)), pairAddress);
        assertEq(factory.getPair(address(token1), address(token0)), pairAddress);
    }

    function testAllPairs() public {
        // Create multiple pairs
        address pair1 = factory.createPair(address(token0), address(token1));
        address pair2 = factory.createPair(address(token1), address(token2));
        address pair3 = factory.createPair(address(token0), address(token2));
        
        assertEq(factory.allPairsLength(), 3);
        assertEq(factory.allPairs(0), pair1);
        assertEq(factory.allPairs(1), pair2);
        assertEq(factory.allPairs(2), pair3);
    }

    function testAllPairsIndexOutOfBounds() public {
        vm.expectRevert();
        factory.allPairs(0);
        
        // Create one pair
        factory.createPair(address(token0), address(token1));
        
        // Should work
        factory.allPairs(0);
        
        // Should fail
        vm.expectRevert();
        factory.allPairs(1);
    }

    function testCreatePairDeterministicAddress() public {
        // Create pair first time
        address pairAddress1 = factory.createPair(address(token0), address(token1));
        
        // Create new factory with same owner
        vm.startPrank(owner);
        AndeSwapFactory factory2 = new AndeSwapFactory(owner);
        vm.stopPrank();
        
        // Create pair with same tokens in new factory
        address pairAddress2 = factory2.createPair(address(token0), address(token1));
        
        // Addresses should be different due to different factory addresses
        assertTrue(pairAddress1 != pairAddress2);
        
        // But both should be valid pairs
        AndeSwapPair pair1 = AndeSwapPair(pairAddress1);
        AndeSwapPair pair2 = AndeSwapPair(pairAddress2);
        
        assertEq(pair1.factory(), address(factory));
        assertEq(pair2.factory(), address(factory2));
    }

    function testCreatePairWithANDEToken() public {
        // Test creating pair with ANDE token
        address pairAddress = factory.createPair(address(ande), address(token0));
        
        assertTrue(pairAddress != address(0));
        
        AndeSwapPair pair = AndeSwapPair(pairAddress);
        assertEq(pair.token0(), address(ande)); // ANDE should be token0 if its address is lower
        assertEq(pair.token1(), address(token0));
    }

    function testGasUsage() public {
        // Measure gas usage for pair creation
        uint256 gasStart = gasleft();
        factory.createPair(address(token0), address(token1));
        uint256 gasUsed = gasStart - gasleft();
        
        // Pair creation should use reasonable amount of gas
        assertTrue(gasUsed < 200000, "Pair creation uses too much gas");
    }

    function testFuzzCreatePair(address tokenA, address tokenB) public {
        // Bound addresses to be non-zero and different
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        vm.assume(tokenA != tokenB);
        
        // Should not revert for valid addresses
        vm.prank(owner);
        address pairAddress = factory.createPair(tokenA, tokenB);
        
        assertTrue(pairAddress != address(0));
        assertEq(factory.getPair(tokenA, tokenB), pairAddress);
        assertEq(factory.getPair(tokenB, tokenA), pairAddress);
    }
}