// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ANDEToken} from "../src/ANDEToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ANDETokenTest is Test {
    ANDEToken public andeToken;
    
    address public owner;
    address public minter;
    address public otherAccount;

    bytes32 public constant ADMIN_ROLE = bytes32(0);
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // 1. Crear direcciones de prueba
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        otherAccount = makeAddr("otherAccount");

        // 2. Desplegar la implementación y el proxy (patrón UUPS)
        ANDEToken implementation = new ANDEToken();
        bytes memory data = abi.encodeWithSelector(
            ANDEToken.initialize.selector,
            owner,
            minter
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        // 3. Apuntar nuestra variable al contrato a través del proxy
        andeToken = ANDEToken(address(proxy));
    }

    // --- Test Group: Deployment and Initialization ---

    function test_Deployment_SetsCorrectRoles() public {
        assertTrue(andeToken.hasRole(ADMIN_ROLE, owner), "Owner should have admin role");
        assertTrue(andeToken.hasRole(MINTER_ROLE, minter), "Minter should have minter role");
    }

    function test_Deployment_HasCorrectNameAndSymbol() public {
        assertEq(andeToken.name(), "ANDE Token", "Name should be ANDE Token");
        assertEq(andeToken.symbol(), "ANDE", "Symbol should be ANDE");
    }

    // --- Test Group: Minting ---

    function test_Minting_MinterCanMint() public {
        uint256 mintAmount = 1000 * 1e18;
        
        vm.prank(minter);
        andeToken.mint(otherAccount, mintAmount);
        
        assertEq(andeToken.balanceOf(otherAccount), mintAmount, "Balance should be mintAmount");
    }

    function test_Minting_NonMinterCannotMint() public {
        uint256 mintAmount = 1000 * 1e18;

        vm.prank(otherAccount);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, otherAccount, MINTER_ROLE)
        );
        andeToken.mint(otherAccount, mintAmount);
    }

    function test_Minting_AdminCannotMintWithoutRole() public {
        uint256 mintAmount = 1000 * 1e18;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, owner, MINTER_ROLE)
        );
        andeToken.mint(otherAccount, mintAmount);
    }

    // --- Test Group: Burning ---

    function test_Burning_HolderCanBurn() public {
        uint256 mintAmount = 1000 * 1e18;
        vm.prank(minter);
        andeToken.mint(otherAccount, mintAmount);

        uint256 initialBalance = andeToken.balanceOf(otherAccount);
        uint256 initialTotalSupply = andeToken.totalSupply();

        uint256 burnAmount = 100 * 1e18;
        vm.prank(otherAccount);
        andeToken.burn(burnAmount);

        assertEq(andeToken.balanceOf(otherAccount), initialBalance - burnAmount, "Balance should decrease by burnAmount");
        assertEq(andeToken.totalSupply(), initialTotalSupply - burnAmount, "Total supply should decrease by burnAmount");
    }

    // --- Test Group: Governance ---

    function test_Governance_CanDelegate() public {
        vm.prank(owner);
        andeToken.delegate(otherAccount);

        assertEq(andeToken.delegates(owner), otherAccount, "Delegation should be set to otherAccount");
    }
}