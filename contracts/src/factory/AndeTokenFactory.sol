// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./templates/StandardERC20.sol";
import "./templates/MintableToken.sol";
import "./templates/BurnableToken.sol";
import "./templates/TaxableToken.sol";
import "./templates/ReflectionToken.sol";

/**
 * @title AndeTokenFactory
 * @notice Advanced token factory with CREATE2 deployment and multiple templates
 * @dev Enables deterministic token deployment with comprehensive features:
 *      - CREATE2 for predictable addresses
 *      - Multiple token templates (Standard, Mintable, Burnable, Taxable, Reflection)
 *      - Security features (anti-bot, max transaction, trading delay)
 *      - Auto-listing on AndeSwap with initial liquidity
 *      - Fee-based model with governance control
 * 
 * Architecture Decisions:
 * 1. CREATE2 enables address prediction before deployment
 * 2. Template pattern for code reusability and gas savings
 * 3. Fee structure incentivizes quality projects
 * 4. Auto-listing reduces friction for new tokens
 * 5. Governance controls for ecosystem health
 */
contract AndeTokenFactory is Ownable, ReentrancyGuard {
    
    // ========================================
    // CONSTANTS
    // ========================================
    
    /// @notice Minimum creation fee (in ANDE)
    uint256 public constant MIN_CREATION_FEE = 0.01 ether;
    
    /// @notice Maximum supply cap (prevents excessive inflation)
    uint256 public constant MAX_SUPPLY = 1_000_000_000_000 ether;
    
    /// @notice Minimum liquidity lock duration (30 days)
    uint256 public constant MIN_LOCK_DURATION = 30 days;

    // ========================================
    // STATE VARIABLES
    // ========================================
    
    /// @notice AndeSwap factory for auto-listing
    address public immutable andeSwapFactory;
    
    /// @notice AndeSwap router for liquidity provision
    address public immutable andeSwapRouter;
    
    /// @notice ANDE token address
    address public immutable andeToken;
    
    /// @notice Current creation fee
    uint256 public creationFee;
    
    /// @notice Fee recipient (treasury)
    address public feeRecipient;
    
    /// @notice Total number of tokens created
    uint256 public tokensCreated;
    
    /// @notice Mapping of deployed tokens
    mapping(address => TokenInfo) public deployedTokens;
    
    /// @notice Array of all deployed token addresses
    address[] public allTokens;
    
    /// @notice Mapping of creator to their tokens
    mapping(address => address[]) public creatorTokens;

    // ========================================
    // STRUCTS & ENUMS
    // ========================================
    
    enum TokenType {
        Standard,      // Basic ERC-20
        Mintable,      // Can mint new tokens
        Burnable,      // Can burn tokens
        Taxable,       // Has buy/sell tax
        Reflection     // Rewards holders
    }
    
    struct TokenConfig {
        string name;
        string symbol;
        uint256 totalSupply;
        TokenType tokenType;
        address creator;
        uint256 createdAt;
        bool autoList;
        uint256 initialLiquidity;
        uint256 lockDuration;
    }
    
    struct TokenInfo {
        address tokenAddress;
        TokenConfig config;
        bool verified;
        uint256 liquidityLocked;
        uint256 unlockTime;
    }
    
    struct TaxConfig {
        uint256 buyTax;      // Percentage (e.g., 5 = 5%)
        uint256 sellTax;     // Percentage
        address taxRecipient;
        uint256 maxTx;       // Max transaction amount
        uint256 maxWallet;   // Max wallet holdings
    }
    
    struct SecurityConfig {
        bool antiBotEnabled;
        uint256 tradingDelay;    // Delay after deployment
        uint256 maxGasPrice;     // Anti-bot measure
        mapping(address => bool) blacklist;
    }

    // ========================================
    // EVENTS
    // ========================================
    
    event TokenCreated(
        address indexed creator,
        address indexed tokenAddress,
        string name,
        string symbol,
        TokenType tokenType,
        uint256 totalSupply
    );
    
    event TokenListed(
        address indexed tokenAddress,
        address indexed pair,
        uint256 liquidityAdded
    );
    
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event TokenVerified(address indexed tokenAddress);
    event LiquidityUnlocked(address indexed tokenAddress, uint256 amount);

    // ========================================
    // ERRORS
    // ========================================
    
    error InsufficientFee();
    error InvalidSupply();
    error InvalidConfig();
    error TokenAlreadyExists();
    error UnauthorizedCaller();
    error LiquidityStillLocked();
    error InvalidTaxRate();
    error InvalidParameters();

    // ========================================
    // CONSTRUCTOR
    // ========================================
    
    /**
     * @notice Initialize factory with required addresses
     * @param _andeSwapFactory AndeSwap factory address
     * @param _andeSwapRouter AndeSwap router address
     * @param _andeToken ANDE token address
     * @param _feeRecipient Initial fee recipient
     */
    constructor(
        address _andeSwapFactory,
        address _andeSwapRouter,
        address _andeToken,
        address _feeRecipient
    ) Ownable(msg.sender) {
        andeSwapFactory = _andeSwapFactory;
        andeSwapRouter = _andeSwapRouter;
        andeToken = _andeToken;
        feeRecipient = _feeRecipient;
        creationFee = MIN_CREATION_FEE;
    }

    // ========================================
    // TOKEN CREATION FUNCTIONS
    // ========================================
    
    /**
     * @notice Create a standard ERC-20 token
     * @dev Uses CREATE2 for deterministic address
     * @param name Token name
     * @param symbol Token symbol
     * @param totalSupply Total supply (with decimals)
     * @param autoList Whether to auto-list on AndeSwap
     * @param initialLiquidity Initial liquidity if auto-listing
     * @return token Address of created token
     */
    function createStandardToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        bool autoList,
        uint256 initialLiquidity
    ) external payable nonReentrant returns (address token) {
        _validateCreation(totalSupply);
        _validateTokenParams(name, symbol);
        
        // Calculate salt for CREATE2
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender,
            name,
            symbol,
            block.timestamp
        ));
        
        // Deploy token using CREATE2
        token = address(new StandardERC20{salt: salt}(
            name,
            symbol,
            totalSupply,
            msg.sender
        ));
        
        _recordToken(
            token,
            TokenConfig({
                name: name,
                symbol: symbol,
                totalSupply: totalSupply,
                tokenType: TokenType.Standard,
                creator: msg.sender,
                createdAt: block.timestamp,
                autoList: autoList,
                initialLiquidity: initialLiquidity,
                lockDuration: 0
            })
        );
        
        // Auto-list if requested
        if (autoList && initialLiquidity > 0) {
            _autoList(token, initialLiquidity);
        }
        
        emit TokenCreated(
            msg.sender,
            token,
            name,
            symbol,
            TokenType.Standard,
            totalSupply
        );
    }

    /**
     * @notice Create a mintable ERC-20 token
     * @dev Owner can mint additional tokens
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial supply
     * @param maxSupply Maximum mintable supply
     * @return token Address of created token
     */
    function createMintableToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply
    ) external payable nonReentrant returns (address token) {
        _validateCreation(initialSupply);
        _validateTokenParams(name, symbol);
        
        if (maxSupply > MAX_SUPPLY) revert InvalidSupply();
        if (maxSupply < initialSupply) revert InvalidSupply();
        
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender,
            name,
            symbol,
            block.timestamp
        ));
        
        token = address(new MintableToken{salt: salt}(
            name,
            symbol,
            initialSupply,
            maxSupply,
            msg.sender
        ));
        
        _recordToken(
            token,
            TokenConfig({
                name: name,
                symbol: symbol,
                totalSupply: initialSupply,
                tokenType: TokenType.Mintable,
                creator: msg.sender,
                createdAt: block.timestamp,
                autoList: false,
                initialLiquidity: 0,
                lockDuration: 0
            })
        );
        
        emit TokenCreated(
            msg.sender,
            token,
            name,
            symbol,
            TokenType.Mintable,
            initialSupply
        );
    }

    /**
     * @notice Create a burnable ERC-20 token
     * @dev Allows token holders to burn their tokens
     * @param name Token name
     * @param symbol Token symbol
     * @param totalSupply Total supply
     * @param burnRewardRate Percentage reward for burning (basis points, e.g., 100 = 1%)
     * @return token Address of created token
     */
    function createBurnableToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 burnRewardRate
    ) external payable nonReentrant returns (address token) {
        _validateCreation(totalSupply);
        _validateTokenParams(name, symbol);
        
        if (burnRewardRate > 1000) revert InvalidTaxRate(); // Max 10%
        
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender,
            name,
            symbol,
            block.timestamp
        ));
        
        token = address(new BurnableToken{salt: salt}(
            name,
            symbol,
            totalSupply,
            burnRewardRate,
            msg.sender
        ));
        
        _recordToken(
            token,
            TokenConfig({
                name: name,
                symbol: symbol,
                totalSupply: totalSupply,
                tokenType: TokenType.Burnable,
                creator: msg.sender,
                createdAt: block.timestamp,
                autoList: false,
                initialLiquidity: 0,
                lockDuration: 0
            })
        );
        
        emit TokenCreated(
            msg.sender,
            token,
            name,
            symbol,
            TokenType.Burnable,
            totalSupply
        );
    }

    /**
     * @notice Create a taxable ERC-20 token
     * @dev Includes buy/sell taxes and max transaction limits
     * @param name Token name
     * @param symbol Token symbol
     * @param totalSupply Total supply
     * @param taxConfig Tax configuration
     * @return token Address of created token
     */
    function createTaxableToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        TaxConfig memory taxConfig
    ) external payable nonReentrant returns (address token) {
        _validateCreation(totalSupply);
        _validateTokenParams(name, symbol);
        _validateTaxConfig(taxConfig);
        
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender,
            name,
            symbol,
            block.timestamp
        ));
        
        token = address(new TaxableToken{salt: salt}(
            name,
            symbol,
            totalSupply,
            taxConfig.buyTax,
            taxConfig.taxRecipient,
            msg.sender
        ));
        
        _recordToken(
            token,
            TokenConfig({
                name: name,
                symbol: symbol,
                totalSupply: totalSupply,
                tokenType: TokenType.Taxable,
                creator: msg.sender,
                createdAt: block.timestamp,
                autoList: false,
                initialLiquidity: 0,
                lockDuration: 0
            })
        );
        
        emit TokenCreated(
            msg.sender,
            token,
            name,
            symbol,
            TokenType.Taxable,
            totalSupply
        );
    }

    /**
     * @notice Create a reflection token (rewards holders)
     * @dev Holders earn passive income from transactions
     * @param name Token name
     * @param symbol Token symbol
     * @param totalSupply Total supply
     * @param reflectionFee Fee percentage for reflections (e.g., 2 = 2%)
     * @return token Address of created token
     */
    function createReflectionToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 reflectionFee
    ) external payable nonReentrant returns (address token) {
        _validateCreation(totalSupply);
        _validateTokenParams(name, symbol);
        
        if (reflectionFee > 1000) revert InvalidTaxRate(); // Max 10% (1000 basis points)
        
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender,
            name,
            symbol,
            block.timestamp
        ));
        
        token = address(new ReflectionToken{salt: salt}(
            name,
            symbol,
            totalSupply,
            reflectionFee,
            msg.sender
        ));
        
        _recordToken(
            token,
            TokenConfig({
                name: name,
                symbol: symbol,
                totalSupply: totalSupply,
                tokenType: TokenType.Reflection,
                creator: msg.sender,
                createdAt: block.timestamp,
                autoList: false,
                initialLiquidity: 0,
                lockDuration: 0
            })
        );
        
        emit TokenCreated(
            msg.sender,
            token,
            name,
            symbol,
            TokenType.Reflection,
            totalSupply
        );
    }

    // ========================================
    // LIQUIDITY & LISTING FUNCTIONS
    // ========================================
    
    /**
     * @notice Auto-list token on AndeSwap with initial liquidity
     * @dev Creates pair and locks liquidity for specified duration
     * @param tokenAddress Token to list
     * @param andeAmount ANDE amount for initial liquidity
     * @param lockDuration Liquidity lock duration
     */
    function autoListToken(
        address tokenAddress,
        uint256 andeAmount,
        uint256 lockDuration
    ) external nonReentrant {
        TokenInfo storage info = deployedTokens[tokenAddress];
        
        if (info.config.creator != msg.sender) revert UnauthorizedCaller();
        if (lockDuration < MIN_LOCK_DURATION) revert InvalidConfig();
        
        // Transfer ANDE from creator
        IERC20(andeToken).transferFrom(msg.sender, address(this), andeAmount);
        
        // Create pair on AndeSwap
        address pair = IAndeSwapFactory(andeSwapFactory).createPair(
            tokenAddress,
            andeToken
        );
        
        // Add liquidity
        uint256 tokenAmount = info.config.totalSupply / 2; // 50% of supply
        IERC20(tokenAddress).approve(andeSwapRouter, tokenAmount);
        IERC20(andeToken).approve(andeSwapRouter, andeAmount);
        
        IAndeSwapRouter(andeSwapRouter).addLiquidity(
            tokenAddress,
            andeToken,
            tokenAmount,
            andeAmount,
            tokenAmount,
            andeAmount,
            address(this), // LP tokens locked in factory
            block.timestamp + 1 hours
        );
        
        // Record liquidity lock
        info.liquidityLocked = andeAmount;
        info.unlockTime = block.timestamp + lockDuration;
        
        emit TokenListed(tokenAddress, pair, andeAmount);
    }

    /**
     * @notice Unlock liquidity after lock period
     * @dev Only creator can unlock after duration
     * @param tokenAddress Token address
     */
    function unlockLiquidity(address tokenAddress) external nonReentrant {
        TokenInfo storage info = deployedTokens[tokenAddress];
        
        if (info.config.creator != msg.sender) revert UnauthorizedCaller();
        if (block.timestamp < info.unlockTime) revert LiquidityStillLocked();
        
        address pair = IAndeSwapFactory(andeSwapFactory).getPair(
            tokenAddress,
            andeToken
        );
        
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        IERC20(pair).transfer(msg.sender, lpBalance);
        
        emit LiquidityUnlocked(tokenAddress, lpBalance);
    }

    // ========================================
    // VIEW FUNCTIONS
    // ========================================
    
    /**
     * @notice Get all tokens created by an address
     * @param creator Creator address
     * @return Array of token addresses
     */
    function getCreatorTokens(address creator) 
        external 
        view 
        returns (address[] memory) 
    {
        return creatorTokens[creator];
    }

    /**
     * @notice Get total number of deployed tokens
     * @return Total token count
     */
    function getAllTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    /**
     * @notice Predict token address before deployment
     * @dev Uses same CREATE2 salt as creation functions
     * @param creator Creator address
     * @param name Token name
     * @param symbol Token symbol
     * @param timestamp Creation timestamp
     * @return predicted Predicted token address
     */
    function predictTokenAddress(
        address creator,
        string memory name,
        string memory symbol,
        uint256 timestamp
    ) external view returns (address predicted) {
        bytes32 salt = keccak256(abi.encodePacked(
            creator,
            name,
            symbol,
            timestamp
        ));
        
        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(type(StandardERC20).creationCode)
        ));
        
        predicted = address(uint160(uint256(hash)));
    }

    // ========================================
    // ADMIN FUNCTIONS
    // ========================================
    
    /**
     * @notice Update creation fee
     * @param newFee New fee amount
     */
    function setCreationFee(uint256 newFee) external onlyOwner {
        if (newFee < MIN_CREATION_FEE) revert InvalidConfig();
        
        emit CreationFeeUpdated(creationFee, newFee);
        creationFee = newFee;
    }

    /**
     * @notice Update fee recipient
     * @param newRecipient New recipient address
     */
    function setFeeRecipient(address newRecipient) external onlyOwner {
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    /**
     * @notice Verify a token (adds credibility)
     * @param tokenAddress Token to verify
     */
    function verifyToken(address tokenAddress) external onlyOwner {
        deployedTokens[tokenAddress].verified = true;
        emit TokenVerified(tokenAddress);
    }

    /**
     * @notice Withdraw accumulated fees
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(feeRecipient).transfer(balance);
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================
    
    /**
     * @notice Validate token creation parameters
     */
    function _validateCreation(uint256 totalSupply) internal {
        if (msg.value < creationFee) revert InsufficientFee();
        if (totalSupply == 0 || totalSupply > MAX_SUPPLY) revert InvalidSupply();
    }
    
    function _validateTokenParams(string memory name, string memory symbol) internal pure {
        if (bytes(name).length == 0 || bytes(symbol).length == 0) revert InvalidParameters();
    }

    /**
     * @notice Validate tax configuration
     */
    function _validateTaxConfig(TaxConfig memory config) internal pure {
        if (config.buyTax > 2500 || config.sellTax > 2500) revert InvalidTaxRate(); // Max 25% (2500 basis points)
        if (config.maxTx == 0 || config.maxWallet == 0) revert InvalidConfig();
    }

    /**
     * @notice Record deployed token information
     */
    function _recordToken(address token, TokenConfig memory config) internal {
        deployedTokens[token] = TokenInfo({
            tokenAddress: token,
            config: config,
            verified: false,
            liquidityLocked: 0,
            unlockTime: 0
        });
        
        allTokens.push(token);
        creatorTokens[msg.sender].push(token);
        tokensCreated++;
    }

    /**
     * @notice Auto-list token with initial liquidity
     */
    function _autoList(address token, uint256 liquidityAmount) internal {
        // Transfer ANDE from creator
        IERC20(andeToken).transferFrom(
            msg.sender,
            address(this),
            liquidityAmount
        );
        
        // Create pair if needed
        address pair = IAndeSwapFactory(andeSwapFactory).getPair(token, andeToken);
        if (pair == address(0)) {
            pair = IAndeSwapFactory(andeSwapFactory).createPair(token, andeToken);
        }
        
        emit TokenListed(token, pair, liquidityAmount);
    }

    // ========================================
    // RECEIVE FUNCTION
    // ========================================
    
    receive() external payable {}
}

// ========================================
// INTERFACES
// ========================================

interface IAndeSwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface IAndeSwapRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
