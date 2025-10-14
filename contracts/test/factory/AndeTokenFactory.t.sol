// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeTokenFactory} from "../../src/factory/AndeTokenFactory.sol";
import {StandardToken} from "../../src/factory/templates/StandardToken.sol";
import {MintableToken} from "../../src/factory/templates/MintableToken.sol";
import {BurnableToken} from "../../src/factory/templates/BurnableToken.sol";
import {TaxableToken} from "../../src/factory/templates/TaxableToken.sol";
import {ReflectionToken} from "../../src/factory/templates/ReflectionToken.sol";

contract AndeTokenFactoryTest is Test {
    AndeTokenFactory public factory;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public feeRecipient = address(0x4);
    
    event TokenCreated(
        address indexed token,
        address indexed creator,
        string name,
        string symbol,
        uint256 indexed tokenType
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    function setUp() public {
        vm.startPrank(owner);
        
        factory = new AndeTokenFactory(feeRecipient);
        
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(factory.owner(), owner);
        assertEq(factory.feeRecipient(), feeRecipient);
        assertEq(factory.creationFee(), 0.01 ether);
        assertEq(factory.tokensCreated(), 0);
    }

    function testCreateStandardToken() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 totalSupply = 1000000 ether;
        
        vm.expectEmit(true, true, true, true);
        emit TokenCreated(address(0), user1, name, symbol, 0);
        
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply
        );
        
        assertTrue(tokenAddress != address(0));
        assertEq(factory.tokensCreated(), 1);
        
        StandardToken token = StandardToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
    }

    function testCreateMintableToken() public {
        string memory name = "Mintable Token";
        string memory symbol = "MINT";
        uint256 initialSupply = 100000 ether;
        
        vm.prank(user1);
        address tokenAddress = factory.createMintableToken{value: 0.01 ether}(
            name,
            symbol,
            initialSupply
        );
        
        MintableToken token = MintableToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(user1), initialSupply);
        assertTrue(token.hasRole(token.MINTER_ROLE(), user1));
    }

    function testCreateBurnableToken() public {
        string memory name = "Burnable Token";
        string memory symbol = "BURN";
        uint256 totalSupply = 500000 ether;
        
        vm.prank(user1);
        address tokenAddress = factory.createBurnableToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply
        );
        
        BurnableToken token = BurnableToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
    }

    function testCreateTaxableToken() public {
        string memory name = "Taxable Token";
        string memory symbol = "TAX";
        uint256 totalSupply = 1000000 ether;
        uint256 taxRate = 200; // 2%
        address taxRecipient = address(0x5);
        
        vm.prank(user1);
        address tokenAddress = factory.createTaxableToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            taxRate,
            taxRecipient
        );
        
        TaxableToken token = TaxableToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
        assertEq(token.getTaxRate(), taxRate);
        assertEq(token.getTaxRecipient(), taxRecipient);
    }

    function testCreateReflectionToken() public {
        string memory name = "Reflection Token";
        string memory symbol = "REFLECT";
        uint256 totalSupply = 1000000 ether;
        uint256 reflectionFee = 100; // 1%
        
        vm.prank(user1);
        address tokenAddress = factory.createReflectionToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            reflectionFee
        );
        
        ReflectionToken token = ReflectionToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
        assertEq(token.getReflectionFee(), reflectionFee);
    }

    function testCreateTokenWithInsufficientFee() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InsufficientFee.selector);
        factory.createStandardToken(
            "Test Token",
            "TEST",
            1000000 ether
        );
    }

    function testCreateTokenWithEmptyName() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "",
            "TEST",
            1000000 ether
        );
    }

    function testCreateTokenWithEmptySymbol() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "",
            1000000 ether
        );
    }

    function testCreateTokenWithZeroSupply() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            0
        );
    }

    function testCreateTokenWithExcessiveSupply() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            10**30 * 10**18 // Exceeds max supply
        );
    }

    function testSetCreationFee() public {
        uint256 newFee = 0.02 ether;
        
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(0.01 ether, newFee);
        
        vm.prank(owner);
        factory.setCreationFee(newFee);
        
        assertEq(factory.creationFee(), newFee);
    }

    function testSetCreationFeeUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        factory.setCreationFee(0.02 ether);
    }

    function testSetFeeRecipient() public {
        address newRecipient = address(0x6);
        
        vm.expectEmit(true, true, true, true);
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        
        vm.prank(owner);
        factory.setFeeRecipient(newRecipient);
        
        assertEq(factory.feeRecipient(), newRecipient);
    }

    function testSetFeeRecipientUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        factory.setFeeRecipient(address(0x6));
    }

    function testWithdrawFees() public {
        // Create some tokens to generate fees
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 1",
            "TEST1",
            1000000 ether
        );
        
        vm.prank(user2);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 2",
            "TEST2",
            1000000 ether
        );
        
        uint256 balanceBefore = feeRecipient.balance;
        
        vm.prank(owner);
        factory.withdrawFees();
        
        assertEq(feeRecipient.balance - balanceBefore, 0.02 ether);
        assertEq(address(factory).balance, 0);
    }

    function testWithdrawFeesUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        factory.withdrawFees();
    }

    function testGetTokenInfo() public {
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            1000000 ether
        );
        
        (address creator, string memory name, string memory symbol, uint256 tokenType, uint256 createdAt) = factory.getTokenInfo(tokenAddress);
        
        assertEq(creator, user1);
        assertEq(name, "Test Token");
        assertEq(symbol, "TEST");
        assertEq(tokenType, 0); // Standard token type
        assertTrue(createdAt > 0);
    }

    function testGetTokenInfoNonExistent() public {
        vm.expectRevert(AndeTokenFactory.TokenNotFound.selector);
        factory.getTokenInfo(address(0x1));
    }

    function testGetUserTokens() public {
        // Create tokens for user1
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 1",
            "TEST1",
            1000000 ether
        );
        
        vm.prank(user1);
        factory.createMintableToken{value: 0.01 ether}(
            "Test Token 2",
            "TEST2",
            500000 ether
        );
        
        // Create token for user2
        vm.prank(user2);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 3",
            "TEST3",
            1000000 ether
        );
        
        address[] memory user1Tokens = factory.getUserTokens(user1);
        address[] memory user2Tokens = factory.getUserTokens(user2);
        
        assertEq(user1Tokens.length, 2);
        assertEq(user2Tokens.length, 1);
    }

    function testGetAllTokens() public {
        // Create multiple tokens
        vm.prank(user1);
        address token1 = factory.createStandardToken{value: 0.01 ether}(
            "Test Token 1",
            "TEST1",
            1000000 ether
        );
        
        vm.prank(user2);
        address token2 = factory.createMintableToken{value: 0.01 ether}(
            "Test Token 2",
            "TEST2",
            500000 ether
        );
        
        address[] memory allTokens = factory.getAllTokens();
        
        assertEq(allTokens.length, 2);
        assertEq(allTokens[0], token1);
        assertEq(allTokens[1], token2);
    }

    function testTokenCreationWithDifferentParameters() public {
        // Test with minimum values
        vm.prank(user1);
        address minToken = factory.createStandardToken{value: 0.01 ether}(
            "Min",
            "MIN",
            1 ether
        );
        
        StandardToken token = StandardToken(minToken);
        assertEq(token.totalSupply(), 1 ether);
        
        // Test with maximum values
        vm.prank(user2);
        address maxToken = factory.createStandardToken{value: 0.01 ether}(
            "Max Token With Long Name",
            "MAX",
            10**25 * 10**18 // 10 million tokens
        );
        
        StandardToken maxTokenContract = StandardToken(maxToken);
        assertEq(maxTokenContract.totalSupply(), 10**25 * 10**18);
    }

    function testTaxableTokenWithInvalidTaxRate() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createTaxableToken{value: 0.01 ether}(
            "Invalid Tax Token",
            "TAX",
            1000000 ether,
            1000, // 10% - too high
            address(0x5)
        );
    }

    function testReflectionTokenWithInvalidFee() public {
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTokenParameters.selector);
        factory.createReflectionToken{value: 0.01 ether}(
            "Invalid Reflection Token",
            "REFLECT",
            1000000 ether,
            1000 // 10% - too high
        );
    }

    function testGasUsage() public {
        uint256 gasStart = gasleft();
        
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Gas Test Token",
            "GAS",
            1000000 ether
        );
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Token creation should use reasonable amount of gas
        assertTrue(gasUsed < 3000000, "Token creation uses too much gas");
    }

    function testFuzzCreateToken(string memory name, string memory symbol, uint256 supply) public {
        // Bound parameters to reasonable values
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        vm.assume(supply >= 1 ether && supply <= 10**25 * 10**18);
        
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            name,
            symbol,
            supply
        );
        
        assertTrue(tokenAddress != address(0));
        
        StandardToken token = StandardToken(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), supply);
    }

    function testEmergencyPause() public {
        // Pause token creation
        vm.prank(owner);
        factory.setPaused(true);
        
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.ContractPaused.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Paused Token",
            "PAUSED",
            1000000 ether
        );
        
        // Unpause
        vm.prank(owner);
        factory.setPaused(false);
        
        // Should work again
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            "Unpaused Token",
            "UNPAUSED",
            1000000 ether
        );
        
        assertTrue(tokenAddress != address(0));
    }

    function testBatchTokenCreation() public {
        // Create multiple tokens in batch
        vm.prank(user1);
        address[] memory tokens = new address[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            tokens[i] = factory.createStandardToken{value: 0.01 ether}(
                string(abi.encodePacked("Token ", i)),
                string(abi.encodePacked("T", i)),
                1000000 ether
            );
        }
        
        assertEq(factory.tokensCreated(), 3);
        
        address[] memory userTokens = factory.getUserTokens(user1);
        assertEq(userTokens.length, 3);
        
        for (uint256 i = 0; i < 3; i++) {
            assertEq(userTokens[i], tokens[i]);
        }
    }
}