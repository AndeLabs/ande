// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {MintableToken} from "../../src/factory/templates/MintableToken.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract MintableTokenTest is Test {
    MintableToken public token;
    
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public pauser = address(0x5);
    
    string public constant NAME = "Mintable Token";
    string public constant SYMBOL = "MINT";
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant MAX_SUPPLY = 2000000 ether;
    uint8 public constant DECIMALS = 18;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        vm.startPrank(owner);
        
        token = new MintableToken(NAME, SYMBOL, INITIAL_SUPPLY, MAX_SUPPLY, owner);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), DECIMALS);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.mintingEnabled(), true);
        assertEq(token.version(), "1.0.0");
        assertEq(token.tokenType(), 1);
        
        // Check roles
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, owner));
        assertTrue(token.hasRole(MINTER_ROLE, owner));
        assertTrue(token.hasRole(PAUSER_ROLE, owner));
    }

    function testTokenInfo() public {
        (
            string memory name_,
            string memory symbol_,
            uint8 decimals_,
            uint256 totalSupply_,
            uint256 maxSupply_,
            bool mintingEnabled_,
            bool paused_,
            string memory version_
        ) = token.getTokenInfo();
        
        assertEq(name_, NAME);
        assertEq(symbol_, SYMBOL);
        assertEq(decimals_, DECIMALS);
        assertEq(totalSupply_, INITIAL_SUPPLY);
        assertEq(maxSupply_, MAX_SUPPLY);
        assertEq(mintingEnabled_, true);
        assertEq(paused_, false);
        assertEq(version_, "1.0.0");
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

    function testMintExceedsMaxSupply() public {
        uint256 mintAmount = MAX_SUPPLY - INITIAL_SUPPLY + 1;
        
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.mint(user1, mintAmount);
        
        vm.stopPrank();
    }

    function testMintWhenDisabled() public {
        vm.startPrank(owner);
        
        token.setMintingEnabled(false);
        
        vm.expectRevert();
        token.mint(user1, 100 ether);
        
        vm.stopPrank();
    }

    function testMintToZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.mint(address(0), 100 ether);
        
        vm.stopPrank();
    }

    function testBatchMint() public {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = minter;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        
        vm.startPrank(owner);
        
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.batchMint(recipients, amounts);
        
        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.balanceOf(user2), 200 ether);
        assertEq(token.balanceOf(minter), 300 ether);
        assertEq(token.totalSupply(), totalSupplyBefore + 600 ether);
        
        vm.stopPrank();
    }

    function testBatchMintExceedsMaxSupply() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = MAX_SUPPLY - INITIAL_SUPPLY;
        amounts[1] = 1 ether;
        
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.batchMint(recipients, amounts);
        
        vm.stopPrank();
    }

    function testBatchMintArrayMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.batchMint(recipients, amounts);
        
        vm.stopPrank();
    }

    function testAddMinter() public {
        vm.startPrank(owner);
        
        token.addMinter(minter);
        
        assertTrue(token.hasRole(MINTER_ROLE, minter));
        assertTrue(token.isMinter(minter));
        
        vm.stopPrank();
    }

    function testAddMinterUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.addMinter(minter);
        
        vm.stopPrank();
    }

    function testAddMinterZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.addMinter(address(0));
        
        vm.stopPrank();
    }

    function testRemoveMinter() public {
        vm.startPrank(owner);
        
        token.addMinter(minter);
        assertTrue(token.hasRole(MINTER_ROLE, minter));
        
        token.removeMinter(minter);
        assertFalse(token.hasRole(MINTER_ROLE, minter));
        assertFalse(token.isMinter(minter));
        
        vm.stopPrank();
    }

    function testRemoveMinterUnauthorized() public {
        vm.startPrank(owner);
        token.addMinter(minter);
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.removeMinter(minter);
        
        vm.stopPrank();
    }

    function testSetMaxSupply() public {
        uint256 newMaxSupply = 3000000 ether;
        
        vm.startPrank(owner);
        
        token.setMaxSupply(newMaxSupply);
        
        assertEq(token.maxSupply(), newMaxSupply);
        
        vm.stopPrank();
    }

    function testSetMaxSupplyUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.setMaxSupply(3000000 ether);
        
        vm.stopPrank();
    }

    function testSetMaxSupplyBelowCurrentSupply() public {
        vm.startPrank(owner);
        
        vm.expectRevert();
        token.setMaxSupply(INITIAL_SUPPLY - 1);
        
        vm.stopPrank();
    }

    function testSetMintingEnabled() public {
        vm.startPrank(owner);
        
        token.setMintingEnabled(false);
        assertEq(token.mintingEnabled(), false);
        
        token.setMintingEnabled(true);
        assertEq(token.mintingEnabled(), true);
        
        vm.stopPrank();
    }

    function testSetMintingEnabledUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.setMintingEnabled(false);
        
        vm.stopPrank();
    }

    function testPause() public {
        vm.startPrank(owner);
        
        token.pause();
        assertTrue(token.paused());
        
        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.pause();
        
        vm.stopPrank();
    }

    function testUnpause() public {
        vm.startPrank(owner);
        
        token.pause();
        assertTrue(token.paused());
        
        token.unpause();
        assertFalse(token.paused());
        
        vm.stopPrank();
    }

    function testUnpauseUnauthorized() public {
        vm.startPrank(owner);
        token.pause();
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.unpause();
        
        vm.stopPrank();
    }

    function testTransferWhenPaused() public {
        vm.startPrank(owner);
        
        token.pause();
        
        vm.expectRevert();
        token.transfer(user1, 100 ether);
        
        vm.stopPrank();
    }

    function testTransferFromWhenPaused() public {
        vm.startPrank(owner);
        
        token.approve(user1, 100 ether);
        token.pause();
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        token.transferFrom(owner, user2, 100 ether);
        
        vm.stopPrank();
    }

    function testMintWhenPaused() public {
        vm.startPrank(owner);
        
        token.pause();
        
        vm.expectRevert();
        token.mint(user1, 100 ether);
        
        vm.stopPrank();
    }

    function testBurnWhenPaused() public {
        vm.startPrank(owner);
        
        token.pause();
        
        vm.expectRevert();
        token.burn(100 ether);
        
        vm.stopPrank();
    }

    function testGetMinterCount() public {
        vm.startPrank(owner);
        
        assertEq(token.getMinterCount(), 1); // Only owner initially
        
        token.addMinter(minter);
        assertEq(token.getMinterCount(), 2);
        
        token.addMinter(user1);
        assertEq(token.getMinterCount(), 3);
        
        token.removeMinter(minter);
        assertEq(token.getMinterCount(), 2);
        
        vm.stopPrank();
    }

    function testIsMinter() public {
        assertTrue(token.isMinter(owner));
        assertFalse(token.isMinter(minter));
        
        vm.startPrank(owner);
        token.addMinter(minter);
        vm.stopPrank();
        
        assertTrue(token.isMinter(minter));
    }

    function testUnlimitedMaxSupply() public {
        vm.startPrank(owner);
        
        MintableToken unlimitedToken = new MintableToken(
            "Unlimited Token",
            "UNLIMITED",
            1000 ether,
            0, // 0 means unlimited
            owner
        );
        
        assertEq(unlimitedToken.maxSupply(), 0);
        
        // Should be able to mint beyond normal limits
        unlimitedToken.mint(user1, 10000000 ether);
        
        vm.stopPrank();
    }

    function testZeroInitialSupply() public {
        vm.startPrank(owner);
        
        MintableToken zeroSupplyToken = new MintableToken(
            "Zero Supply Token",
            "ZERO",
            0,
            1000000 ether,
            owner
        );
        
        assertEq(zeroSupplyToken.totalSupply(), 0);
        assertEq(zeroSupplyToken.balanceOf(owner), 0);
        
        // Should be able to mint after creation
        zeroSupplyToken.mint(user1, 100 ether);
        assertEq(zeroSupplyToken.totalSupply(), 100 ether);
        assertEq(zeroSupplyToken.balanceOf(user1), 100 ether);
        
        vm.stopPrank();
    }

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount > 0 && amount <= MAX_SUPPLY - INITIAL_SUPPLY);
        
        vm.startPrank(owner);
        
        uint256 balanceBefore = token.balanceOf(to);
        uint256 totalSupplyBefore = token.totalSupply();
        
        token.mint(to, amount);
        
        assertEq(token.balanceOf(to), balanceBefore + amount);
        assertEq(token.totalSupply(), totalSupplyBefore + amount);
        
        vm.stopPrank();
    }

    function testFuzzBatchMint(uint256 count) public {
        vm.assume(count > 0 && count <= 10);
        
        address[] memory recipients = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            recipients[i] = address(uint160(0x10000 + i));
            amounts[i] = (i + 1) * 10 ether;
        }
        
        vm.startPrank(owner);
        
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 totalMintAmount = 0;
        
        for (uint256 i = 0; i < count; i++) {
            totalMintAmount += amounts[i];
        }
        
        if (totalSupplyBefore + totalMintAmount <= MAX_SUPPLY) {
            token.batchMint(recipients, amounts);
            
            for (uint256 i = 0; i < count; i++) {
                assertEq(token.balanceOf(recipients[i]), amounts[i]);
            }
            
            assertEq(token.totalSupply(), totalSupplyBefore + totalMintAmount);
        }
        
        vm.stopPrank();
    }

    function testGasUsage() public {
        vm.startPrank(owner);
        
        uint256 gasStart = gasleft();
        token.mint(user1, 100 ether);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Mint gas used:", gasUsed);
        assertTrue(gasUsed < 200000, "Mint should use less than 200k gas");
        
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = minter;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;
        
        gasStart = gasleft();
        token.batchMint(recipients, amounts);
        gasUsed = gasStart - gasleft();
        
        console.log("Batch mint gas used:", gasUsed);
        assertTrue(gasUsed < 500000, "Batch mint should use less than 500k gas");
        
        vm.stopPrank();
    }

    function testRoleHierarchy() public {
        vm.startPrank(owner);
        
        // Add minter
        token.addMinter(minter);
        
        // Add pauser
        token.grantRole(PAUSER_ROLE, pauser);
        
        // Test that minter can mint but not pause
        vm.startPrank(minter);
        token.mint(user1, 100 ether);
        
        vm.expectRevert();
        token.pause();
        vm.stopPrank();
        
        // Test that pauser can pause but not mint
        vm.startPrank(pauser);
        token.pause();
        
        vm.expectRevert();
        token.mint(user1, 100 ether);
        vm.stopPrank();
        
        vm.startPrank(owner);
        token.unpause();
        vm.stopPrank();
    }

    function testEmergencyScenarios() public {
        vm.startPrank(owner);
        
        // Pause contract in emergency
        token.pause();
        
        // Only owner should be able to unpause
        vm.startPrank(minter);
        vm.expectRevert();
        token.unpause();
        vm.stopPrank();
        
        // Owner can unpause
        vm.startPrank(owner);
        token.unpause();
        
        // Disable minting in emergency
        token.setMintingEnabled(false);
        
        // Even minter cannot mint when disabled
        vm.startPrank(minter);
        vm.expectRevert();
        token.mint(user1, 100 ether);
        vm.stopPrank();
        
        vm.stopPrank();
    }
}