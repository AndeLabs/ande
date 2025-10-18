// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {ANDEToken} from "../../src/ANDETokenDuality.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ANDETokenFuzzTest is Test {
    ANDEToken public token;
    ANDEToken public tokenImpl;
    
    address public admin;
    address public minter;
    
    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        
        tokenImpl = new ANDEToken();
        
        bytes memory initData = abi.encodeWithSelector(
            ANDEToken.initialize.selector,
            admin,
            minter
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(tokenImpl),
            initData
        );
        
        token = ANDEToken(address(proxy));
    }
    
    function testFuzz_MintAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        address recipient = makeAddr("recipient");
        
        vm.prank(minter);
        token.mint(recipient, amount);
        
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), amount);
    }
    
    function testFuzz_Transfer(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        vm.prank(minter);
        token.mint(from, amount);
        
        vm.prank(from);
        token.transfer(to, amount);
        
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), amount);
    }
    
    function testFuzz_TransferPartial(address from, address to, uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);
        
        vm.prank(minter);
        token.mint(from, mintAmount);
        
        vm.prank(from);
        token.transfer(to, transferAmount);
        
        assertEq(token.balanceOf(from), mintAmount - transferAmount);
        assertEq(token.balanceOf(to), transferAmount);
        assertEq(token.totalSupply(), mintAmount);
    }
    
    function testFuzz_Approve(address owner, address spender, uint256 amount) public {
        vm.assume(owner != address(0) && spender != address(0));
        vm.assume(amount <= type(uint128).max);
        
        vm.prank(owner);
        token.approve(spender, amount);
        
        assertEq(token.allowance(owner, spender), amount);
    }
    
    function testFuzz_TransferFrom(address owner, address spender, address recipient, uint256 amount) public {
        vm.assume(owner != address(0) && spender != address(0) && recipient != address(0));
        vm.assume(owner != recipient);
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        vm.prank(minter);
        token.mint(owner, amount);
        
        vm.prank(owner);
        token.approve(spender, amount);
        
        vm.prank(spender);
        token.transferFrom(owner, recipient, amount);
        
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.allowance(owner, spender), 0);
    }
    
    function testFuzz_BurnWithRole(address burner, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(burner != address(0));
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);
        
        vm.prank(admin);
        token.grantRole(token.BURNER_ROLE(), burner);
        
        vm.prank(minter);
        token.mint(burner, mintAmount);
        
        vm.prank(burner);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(burner), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }
    
    function testFuzz_RevertTransferExceedsBalance(address from, address to, uint256 balance, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(balance < type(uint128).max);
        vm.assume(amount > balance && amount <= type(uint128).max);
        
        vm.prank(minter);
        token.mint(from, balance);
        
        vm.expectRevert();
        vm.prank(from);
        token.transfer(to, amount);
    }
    
    function testFuzz_RevertTransferFromExceedsAllowance(
        address owner,
        address spender,
        uint256 allowance,
        uint256 amount
    ) public {
        vm.assume(owner != address(0) && spender != address(0));
        vm.assume(allowance < type(uint128).max);
        vm.assume(amount > allowance && amount <= type(uint128).max);
        
        vm.prank(minter);
        token.mint(owner, amount);
        
        vm.prank(owner);
        token.approve(spender, allowance);
        
        vm.expectRevert();
        vm.prank(spender);
        token.transferFrom(owner, makeAddr("recipient"), amount);
    }
    
    function testFuzz_MultipleTransfers(
        address[5] memory recipients,
        uint256[5] memory amounts
    ) public {
        uint256 totalMinted;
        
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(recipients[i] != address(0));
            vm.assume(amounts[i] > 0 && amounts[i] <= type(uint64).max);
            totalMinted += amounts[i];
        }
        
        vm.assume(totalMinted <= type(uint128).max);
        
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(minter);
            token.mint(recipients[i], amounts[i]);
            assertEq(token.balanceOf(recipients[i]), amounts[i]);
        }
        
        assertEq(token.totalSupply(), totalMinted);
    }
}
