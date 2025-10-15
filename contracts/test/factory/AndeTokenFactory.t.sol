// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {AndeTokenFactory} from "../../src/factory/AndeTokenFactory.sol";
import {StandardToken} from "../../src/factory/templates/StandardToken.sol";
import {MintableToken} from "../../src/factory/templates/MintableToken.sol";
import {BurnableToken} from "../../src/factory/templates/BurnableToken.sol";
import {TaxableToken} from "../../src/factory/templates/TaxableToken.sol";
import {ReflectionToken} from "../../src/factory/templates/ReflectionToken.sol";
import {AndeSwapFactory} from "../../src/dex/AndeSwapFactory.sol";
import {AndeSwapRouter} from "../../src/dex/AndeSwapRouter.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

contract AndeTokenFactoryTest is Test {
    AndeTokenFactory public factory;
    AndeSwapFactory public andeSwapFactory;
    AndeSwapRouter public andeSwapRouter;
    ERC20Mock public andeToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public feeRecipient = address(0x4);
    
    event TokenCreated(
        address indexed creator,
        address indexed tokenAddress,
        string name,
        string symbol,
        TokenType indexed tokenType,
        uint256 totalSupply
    );
    
    enum TokenType {
        Standard,
        Mintable,
        Burnable,
        Taxable,
        Reflection
    }
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);

    function setUp() public {
        vm.startPrank(owner);
        
        andeToken = new ERC20Mock("ANDE", "ANDE");
        andeToken.mint(owner, 1000000 ether);
        
        andeSwapFactory = new AndeSwapFactory(owner);
        andeSwapRouter = new AndeSwapRouter(address(andeSwapFactory));
        
        factory = new AndeTokenFactory(
            address(andeSwapFactory),
            address(andeSwapRouter),
            address(andeToken),
            feeRecipient
        );
        
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
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            false,
            0
        );
        
        assertTrue(tokenAddress != address(0));
        assertEq(factory.tokensCreated(), 1);
        
        StandardToken token = StandardToken(payable(tokenAddress));
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
    }

    function testCreateMintableToken() public {
        string memory name = "Mintable Token";
        string memory symbol = "MINT";
        uint256 initialSupply = 100000 ether;
        uint256 maxSupply = 1000000 ether;
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createMintableToken{value: 0.01 ether}(
            name,
            symbol,
            initialSupply,
            maxSupply
        );
        
        MintableToken token = MintableToken(payable(tokenAddress));
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
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createBurnableToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            100
        );
        
        BurnableToken token = BurnableToken(payable(tokenAddress));
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(user1), totalSupply);
    }

    function testCreateTaxableToken() public {
        string memory name = "Taxable Token";
        string memory symbol = "TAX";
        uint256 totalSupply = 1000000 ether;
        uint256 taxRate = 200;
        address taxRecipient = address(0x5);
        
        AndeTokenFactory.TaxConfig memory taxConfig = AndeTokenFactory.TaxConfig({
            buyTax: taxRate,
            sellTax: taxRate,
            taxRecipient: taxRecipient,
            maxTx: totalSupply / 100,
            maxWallet: totalSupply / 50
        });
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createTaxableToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            taxConfig
        );
        
        TaxableToken token = TaxableToken(payable(tokenAddress));
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
        uint256 reflectionFee = 100;
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createReflectionToken{value: 0.01 ether}(
            name,
            symbol,
            totalSupply,
            reflectionFee
        );
        
        ReflectionToken token = ReflectionToken(payable(tokenAddress));
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
            1000000 ether,
            false,
            0
        );
    }

    function testCreateTokenWithEmptyName() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "",
            "TEST",
            1000000 ether,
            false,
            0
        );
    }

    function testCreateTokenWithEmptySymbol() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidParameters.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "",
            1000000 ether,
            false,
            0
        );
    }

    function testCreateTokenWithZeroSupply() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidSupply.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            0,
            false,
            0
        );
    }

    function testCreateTokenWithExcessiveSupply() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidSupply.selector);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            10**30 * 10**18 // Exceeds max supply
        ,
            false,
            0
        );
    }

    function testSetCreationFee() public {
        uint256 newFee = 0.02 ether;
        
        vm.expectEmit(true, true, true, true);
        emit CreationFeeUpdated(0.01 ether, newFee);
        
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
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        
        // Create some tokens to generate fees
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 1",
            "TEST1",
            1000000 ether,
            false,
            0
        );
        
        vm.prank(user2);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 2",
            "TEST2",
            1000000 ether,
            false,
            0
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
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            "Test Token",
            "TEST",
            1000000 ether,
            false,
            0
        );
        
        (address token, AndeTokenFactory.TokenConfig memory config,, uint256 liquidityLocked, uint256 unlockTime) = factory.deployedTokens(tokenAddress);
        
        assertEq(token, tokenAddress);
        assertEq(config.creator, user1);
        assertEq(config.name, "Test Token");
        assertEq(config.symbol, "TEST");
        assertTrue(config.createdAt > 0);
    }

    function testGetTokenInfoNonExistent() public {
        (address token,,,, ) = factory.deployedTokens(address(0x1));
        assertEq(token, address(0));
    }

    function testGetUserTokens() public {
        // Give users ANDE for fees
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        
        // Create tokens for user1
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 1",
            "TEST1",
            1000000 ether,
            false,
            0
        );
        
        vm.prank(user1);
        factory.createMintableToken{value: 0.01 ether}(
            "Test Token 2",
            "TEST2",
            500000 ether,
            500000 ether * 2
        );
        
        // Create token for user2
        vm.prank(user2);
        factory.createStandardToken{value: 0.01 ether}(
            "Test Token 3",
            "TEST3",
            1000000 ether,
            false,
            0
        );
        
        address[] memory user1Tokens = factory.getCreatorTokens(user1);
        address[] memory user2Tokens = factory.getCreatorTokens(user2);
        
        assertEq(user1Tokens.length, 2);
        assertEq(user2Tokens.length, 1);
    }

    function testGetAllTokens() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address token1 = factory.createStandardToken{value: 0.01 ether}(
            "Token 1",
            "TK1",
            1000000 ether,
            false,
            0
        );
        
        uint256 length = factory.getAllTokensLength();
        assertEq(length, 1);
        assertEq(factory.allTokens(0), token1);
    }

    function testTokenCreationWithDifferentParameters() public {
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        
        // Test with minimum values
        vm.prank(user1);
        address minToken = factory.createStandardToken{value: 0.01 ether}(
            "Min",
            "MIN",
            1 ether,
            false,
            0
        );
        
        StandardToken token = StandardToken(payable(minToken));
        assertEq(token.totalSupply(), 1 ether);
        
        // Test with large values
        vm.prank(user2);
        address maxToken = factory.createStandardToken{value: 0.01 ether}(
            "Max Token With Long Name",
            "MAX",
            1000000 ether,
            false,
            0
        );
        
        StandardToken maxTokenContract = StandardToken(payable(maxToken));
        assertEq(maxTokenContract.totalSupply(), 1000000 ether);
    }

    function testTaxableTokenWithInvalidTaxRate() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTaxRate.selector);
        
        AndeTokenFactory.TaxConfig memory taxConfig = AndeTokenFactory.TaxConfig({
            buyTax: 2600, // 26% - exceeds max of 25%
            sellTax: 2600,
            taxRecipient: address(0x5),
            maxTx: 1000 ether,
            maxWallet: 2000 ether
        });
        
        factory.createTaxableToken{value: 0.01 ether}(
            "Invalid Tax Token",
            "TAX",
            1000000 ether,
            taxConfig
        );
    }

    function testReflectionTokenWithInvalidFee() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(AndeTokenFactory.InvalidTaxRate.selector);
        factory.createReflectionToken{value: 0.01 ether}(
            "Invalid Reflection Token",
            "REFLECT",
            1000000 ether,
            1100 // 11% - too high (max is 10% = 1000 basis points)
        );
    }

    function testGasUsage() public {
        vm.deal(user1, 1 ether);
        
        uint256 gasStart = gasleft();
        
        vm.prank(user1);
        factory.createStandardToken{value: 0.01 ether}(
            "Gas Test Token",
            "GAS",
            1000000 ether,
            false,
            0
        );
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Token creation should use reasonable amount of gas
        assertTrue(gasUsed < 3000000, "Token creation uses too much gas");
    }

    function testFuzzCreateToken(string memory name, string memory symbol, uint256 supply) public {
        // Bound parameters to reasonable values
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        vm.assume(supply >= 1 ether && supply <= 1_000_000_000_000 ether);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        address tokenAddress = factory.createStandardToken{value: 0.01 ether}(
            name,
            symbol,
            supply,
            false,
            0
        );
        
        assertTrue(tokenAddress != address(0));
        
        StandardToken token = StandardToken(payable(tokenAddress));
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), supply);
    }



    function testBatchTokenCreation() public {
        // Create multiple tokens in batch
        address[] memory tokens = new address[](3);
        
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        
        for (uint256 i = 0; i < 3; i++) {
            tokens[i] = factory.createStandardToken{value: 0.01 ether}(
                string(abi.encodePacked("Token ", i)),
                string(abi.encodePacked("T", i)),
                1000000 ether,
                false,
                0
            );
        }
        
        vm.stopPrank();
        
        assertEq(factory.tokensCreated(), 3);
        
        // Verify all tokens were created
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(tokens[i] != address(0));
        }
        
        // Verify creator tokens tracking
        address[] memory userTokens = factory.getCreatorTokens(user1);
        assertEq(userTokens.length, 3);
        
        for (uint256 i = 0; i < 3; i++) {
            assertEq(userTokens[i], tokens[i]);
        }
    }
}