// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ANDEToken} from "../../src/ANDEToken.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract ANDETokenTest is Test {
    ANDEToken public andeToken;
    
    address public owner;
    address public minter;
    address public otherAccount;

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        otherAccount = makeAddr("otherAccount");

        ANDEToken implementation = new ANDEToken();
        bytes memory data = abi.encodeWithSelector(ANDEToken.initialize.selector, owner, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        andeToken = ANDEToken(address(proxy));
    }

    function test_Deployment_SetsCorrectRoles() public view {
        assertTrue(andeToken.hasRole(ADMIN_ROLE, owner));
        assertTrue(andeToken.hasRole(MINTER_ROLE, minter));
    }

    function test_Deployment_HasCorrectNameAndSymbol() public view {
        assertEq(andeToken.name(), "ANDE Token");
        assertEq(andeToken.symbol(), "ANDE");
    }

    function test_Minting_MinterCanMint() public {
        uint256 mintAmount = 1000 * 1e18;
        vm.prank(minter);
        andeToken.mint(otherAccount, mintAmount);
        assertEq(andeToken.balanceOf(otherAccount), mintAmount);
    }

    function test_Minting_NonMinterCannotMint() public {
        uint256 mintAmount = 1000 * 1e18;
        vm.prank(otherAccount);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, otherAccount, MINTER_ROLE));
        andeToken.mint(otherAccount, mintAmount);
    }
}
