// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ANDETokenDuality} from "../../src/ANDETokenDuality.sol";
import {NativeTransferPrecompileMock} from "../../src/mocks/NativeTransferPrecompileMock.sol";

/**
 * @title ANDETokenTestHelper  
 * @notice Helper for deploying ANDETokenDuality with precompile mock
 * @dev Standard pattern for all ANDE token tests - ensures production-ready setup
 */
abstract contract ANDETokenTestHelper is Test {
    
    /**
     * @notice Deploy ANDETokenDuality with precompile mock
     * @dev Follows the exact pattern from TokenDuality.t.sol (our reference test)
     */
    function deployANDEToken(address admin, address minter) 
        internal 
        returns (ANDETokenDuality token, NativeTransferPrecompileMock precompile) 
    {
        // Deploy implementation
        ANDETokenDuality tokenImpl = new ANDETokenDuality();
        
        // Deploy temporary precompile
        NativeTransferPrecompileMock tempPrecompile = new NativeTransferPrecompileMock(address(1));
        
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            ANDETokenDuality.initialize.selector,
            admin,
            minter,
            address(tempPrecompile)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenImpl), initData);
        token = ANDETokenDuality(address(proxy));
        
        // Recreate precompile with correct authorized caller
        precompile = new NativeTransferPrecompileMock(address(token));
        
        // Update precompile address
        vm.prank(admin);
        token.setPrecompileAddress(address(precompile));
    }
    
    /**
     * @notice Deploy ANDETokenDuality and mint initial supply
     * @dev Mints via token.mint() which uses precompile internally
     */
    function deployANDETokenWithSupply(
        address admin,
        address minter,
        uint256 initialSupply
    ) 
        internal 
        returns (ANDETokenDuality token, NativeTransferPrecompileMock precompile) 
    {
        (token, precompile) = deployANDEToken(admin, minter);
        
        // Mint via token contract (production-like)
        vm.prank(minter);
        token.mint(minter, initialSupply);
    }
}
