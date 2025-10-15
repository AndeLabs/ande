// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {StandardToken} from "../../src/factory/templates/StandardToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract StandardTokenTest is Test {
    StandardToken public token;
    ERC20Mock public underlyingToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    string public constant NAME = "Test Token";
    string public constant SYMBOL = "TEST";
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint8 public constant DECIMALS = 18;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        vm.startPrank(owner);
        
        token = new StandardToken(NAME, SYMBOL, INITIAL_SUPPLY, owner);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), DECIMALS);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
        assertEq(token.version(), "1.0.0");
        assertEq(token.tokenType(), 0);
    }

    function testTokenInfo() public {
        (
            string memory name_,
            string memory symbol_,
            uint8 decimals_,
            uint256 totalSupply_,
            address owner_,
            string memory version_
        ) = token.getTokenInfo();
        
        assertEq(name_, NAME);
        assertEq(symbol_, SYMBOL);
        assertEq(decimals_, DECIMALS);
        assertEq(totalSupply_, INITIAL_SUPPLY);
        assertEq(owner_, owner);
        assertEq(version_, "1.0.0");
    }

    function testTransfer() public {
        uint256 transferAmount = 100 ether;
        
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(owner, user1, transferAmount);
        
        bool success = token.transfer(user1, transferAmount);
        
        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user1), transferAmount);
        
        vm.stopPrank();
    }

    function testTransferInsufficientBalance() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.transfer(user1, INITIAL_SUPPLY + 1);
        
        vm.stopPrank();
    }

    function testTransferToZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.transfer(address(0), 100 ether);
        
        vm.stopPrank();
    }

    function testApprove() public {
        uint256 approveAmount = 100 ether;
        
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit Approval(owner, user1, approveAmount);
        
        bool success = token.approve(user1, approveAmount);
        
        assertTrue(success);
        assertEq(token.allowance(owner, user1), approveAmount);
        
        vm.stopPrank();
    }

    function testTransferFrom() public {
        uint256 approveAmount = 100 ether;
        uint256 transferAmount = 50 ether;
        
        vm.startPrank(owner);
        token.approve(user1, approveAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(owner, user2, transferAmount);
        
        bool success = token.transferFrom(owner, user2, transferAmount);
        
        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(owner, user1), approveAmount - transferAmount);
        
        vm.stopPrank();
    }

    function testTransferFromInsufficientAllowance() public {
        uint256 approveAmount = 100 ether;
        
        vm.startPrank(owner);
        token.approve(user1, approveAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.transferFrom(owner, user2, approveAmount + 1);
        
        vm.stopPrank();
    }

    function testBurn() public {
        uint256 burnAmount = 100 ether;
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(owner);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        
        vm.stopPrank();
    }

    function testBurnInsufficientBalance() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.burn(INITIAL_SUPPLY + 1);
        
        vm.stopPrank();
    }

    function testBurnFrom() public {
        uint256 approveAmount = 100 ether;
        uint256 burnAmount = 50 ether;
        
        vm.startPrank(owner);
        token.approve(user1, approveAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        uint256 balanceBefore = token.balanceOf(owner);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.burnFrom(owner, burnAmount);
        
        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        assertEq(token.allowance(owner, user1), approveAmount - burnAmount);
        
        vm.stopPrank();
    }

    function testBurnFromInsufficientAllowance() public {
        uint256 approveAmount = 100 ether;
        
        vm.startPrank(owner);
        token.approve(user1, approveAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.burnFrom(owner, approveAmount + 1);
        
        vm.stopPrank();
    }

    function testMint() public {
        uint256 mintAmount = 100 ether;
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(user1);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.mint(user1, mintAmount);
        
        assertEq(token.balanceOf(user1), balanceBefore + mintAmount);
        assertEq(token.totalSupply(), totalSupplyBefore + mintAmount);
        
        vm.stopPrank();
    }

    function testMintUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.mint(user2, 100 ether);
        
        vm.stopPrank();
    }

    function testMintToZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.mint(address(0), 100 ether);
        
        vm.stopPrank();
    }

    function testRescueTokens() public {
        // Deploy a mock token to rescue
        ERC20Mock mockToken = new ERC20Mock("Mock", "MOCK");
        
        // Send some mock tokens to the StandardToken contract
        vm.startPrank(address(this));
        mockToken.transfer(address(token), 100 ether);
        vm.stopPrank();
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = mockToken.balanceOf(owner);
        
        token.rescueTokens(address(mockToken), 100 ether);
        
        assertEq(mockToken.balanceOf(owner), balanceBefore + 100 ether);
        assertEq(mockToken.balanceOf(address(token)), 0);
        
        vm.stopPrank();
    }

    function testRescueTokensUnauthorized() public {
        ERC20Mock mockToken = new ERC20Mock("Mock", "MOCK");
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.rescueTokens(address(mockToken), 100 ether);
        
        vm.stopPrank();
    }

    function testRescueOwnToken() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.rescueTokens(address(token), 100 ether);
        
        vm.stopPrank();
    }

    function testRescueETH() public {
        vm.startPrank(owner);
        
        // Send ETH to the contract
        vm.deal(address(token), 1 ether);
        
        uint256 balanceBefore = owner.balance;
        
        token.rescueTokens(address(0), 0.5 ether);
        
        assertEq(owner.balance, balanceBefore + 0.5 ether);
        assertEq(address(token).balance, 0.5 ether);
        
        vm.stopPrank();
    }

    function testReceiveETH() public {
        vm.startPrank(owner);
        
        uint256 balanceBefore = address(token).balance;
        
        vm.deal(address(token), 1 ether);
        
        assertEq(address(token).balance, balanceBefore + 1 ether);
        
        vm.stopPrank();
    }

    function testSupportsInterface() public {
        // Test ERC20 interface
        assertTrue(token.supportsInterface(type(IERC20).interfaceId));
        
        // Test Ownable interface
        assertTrue(token.supportsInterface(type(IOwnable).interfaceId));
        
        // Test invalid interface
        assertFalse(token.supportsInterface(0xffffffff));
    }

    function testFuzzTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(owner);
        
        token.transfer(to, amount);
        
        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(owner), balanceBefore - amount);
        
        vm.stopPrank();
    }

    function testFuzzApprove(address spender, uint256 amount) public {
        vm.assume(spender != address(0));
        vm.assume(spender != address(token));
        
        vm.startPrank(owner);
        
        token.approve(spender, amount);
        
        assertEq(token.allowance(owner, spender), amount);
        
        vm.stopPrank();
    }

    function testFuzzBurn(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(owner);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.burn(amount);
        
        assertEq(token.balanceOf(owner), balanceBefore - amount);
        assertEq(token.totalSupply(), totalSupplyBefore - amount);
        
        vm.stopPrank();
    }

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount > 0 && amount <= 1000000 ether);
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(to);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.mint(to, amount);
        
        assertEq(token.balanceOf(to), balanceBefore + amount);
        assertEq(token.totalSupply(), totalSupplyBefore + amount);
        
        vm.stopPrank();
    }

    function testBatchOperations() public {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 10 ether;
        amounts[1] = 20 ether;
        amounts[2] = 30 ether;
        amounts[3] = 40 ether;
        amounts[4] = 50 ether;
        
        address[] memory recipients = new address[](5);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;
        recipients[3] = user1;
        recipients[4] = user2;
        
        vm.startPrank(owner);
        
        for (uint256 i = 0; i < amounts.length; i++) {
            token.transfer(recipients[i], amounts[i]);
        }
        
        assertEq(token.balanceOf(user1), amounts[0] + amounts[3]);
        assertEq(token.balanceOf(user2), amounts[1] + amounts[4]);
        assertEq(token.balanceOf(user3), amounts[2]);
        
        vm.stopPrank();
    }

    function testEdgeCases() public {
        vm.startPrank(owner);
        
        // Transfer zero amount
        token.transfer(user1, 0);
        assertEq(token.balanceOf(user1), 0);
        
        // Approve zero amount
        token.approve(user1, 0);
        assertEq(token.allowance(owner, user1), 0);
        
        // Burn zero amount
        uint256 balanceBefore = token.balanceOf(owner);
        token.burn(0);
        assertEq(token.balanceOf(owner), balanceBefore);
        
        vm.stopPrank();
    }

    function testGasUsage() public {
        vm.startPrank(owner);
        
        uint256 gasStart = gasleft();
        token.transfer(user1, 100 ether);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Transfer gas used:", gasUsed);
        assertTrue(gasUsed < 100000, "Transfer should use less than 100k gas");
        
        gasStart = gasleft();
        token.approve(user1, 100 ether);
        gasUsed = gasStart - gasleft();
        
        console.log("Approve gas used:", gasUsed);
        assertTrue(gasUsed < 100000, "Approve should use less than 100k gas");
        
        gasStart = gasleft();
        token.mint(user1, 100 ether);
        gasUsed = gasStart - gasleft();
        
        console.log("Mint gas used:", gasUsed);
        assertTrue(gasUsed < 100000, "Mint should use less than 100k gas");
        
        vm.stopPrank();
    }
}

interface IOwnable {
    function owner() external view returns (address);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}