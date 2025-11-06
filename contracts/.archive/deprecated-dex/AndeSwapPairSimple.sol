// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AndeSwapLibrary.sol";

/**
 * @title AndeSwapPairSimple
 * @dev Simplified AMM pair contract for AndeSwap
 * @notice This is a basic AMM implementation with core functionality
 * @author AndeChain Team
 */
contract AndeSwapPairSimple is IERC20, IERC20Permit, ReentrancyGuard, Ownable {
    using AndeSwapLibrary for uint256;
    
    // ERC20 basic variables
    string public constant name = "AndeSwap LP Token";
    string public constant symbol = "ANDE-LP";
    uint8 public constant decimals = 18;
    
    uint256 private _totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // AMM variables
    address public factory;
    address public token0;
    address public token1;
    
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    
    // EIP-712 variables for permit
    bytes32 private _DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
    
    mapping(address => uint256) private _nonces;
    
    // Events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // Minimum liquidity constant
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    constructor() Ownable(msg.sender) {
        factory = msg.sender;
    }

    /**
     * @dev Initializes the pair
     * @param _token0 The first token address
     * @param _token1 The second token address
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "AndeSwapPair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
        
        // Initialize EIP-712 domain separator
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Returns the current reserves
     * @return _reserve0 The reserve of token0
     * @return _reserve1 The reserve of token1
     * @return _blockTimestampLast The last block timestamp
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Returns the cumulative prices
     * @return _price0CumulativeLast The cumulative price of token0
     * @return _price1CumulativeLast The cumulative price of token1
     */
    function getPriceCumulativeLast() external view returns (uint256 _price0CumulativeLast, uint256 _price1CumulativeLast) {
        _price0CumulativeLast = price0CumulativeLast;
        _price1CumulativeLast = price1CumulativeLast;
    }

    /**
     * @dev Adds liquidity to the pool
     * @param to The address to receive LP tokens
     * @return liquidity The amount of liquidity tokens minted
     */
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        require(to != address(0), "AndeSwapPair: ZERO_ADDRESS");
        
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        
        uint256 __totalSupply = _totalSupply;
        if (__totalSupply == 0) {
            liquidity = AndeSwapLibrary.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = AndeSwapLibrary.min(
                (amount0 * __totalSupply) / _reserve0,
                (amount1 * __totalSupply) / _reserve1
            );
        }
        
        require(liquidity > 0, "AndeSwapPair: INSUFFICIENT_LIQUIDITY_MINTED");
        
        _mint(to, liquidity);
        
        _update(balance0, balance1, _reserve0, _reserve1);
        
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev Removes liquidity from the pool
     * @param to The address to receive tokens
     * @return amount0 The amount of token0 received
     * @return amount1 The amount of token1 received
     */
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(to != address(0), "AndeSwapPair: ZERO_ADDRESS");
        
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        
        uint256 __totalSupply = _totalSupply;
        amount0 = (liquidity * balance0) / __totalSupply;
        amount1 = (liquidity * balance1) / __totalSupply;
        
        require(amount0 > 0 && amount1 > 0, "AndeSwapPair: INSUFFICIENT_LIQUIDITY_BURNED");
        
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        
        _update(balance0, balance1, _reserve0, _reserve1);
        
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev Swaps tokens
     * @param amount0Out The amount of token0 to send out
     * @param amount1Out The amount of token1 to send out
     * @param to The recipient address
     * @param data Additional data (unused)
     */
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external nonReentrant {
        require(to != address(0), "AndeSwapPair: ZERO_ADDRESS");
        require(amount0Out > 0 || amount1Out > 0, "AndeSwapPair: INSUFFICIENT_OUTPUT_AMOUNT");
        
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "AndeSwapPair: INSUFFICIENT_LIQUIDITY");
        
        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            
            require(to != _token0 && to != _token1, "AndeSwapPair: INVALID_TO");
            
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            if (data.length > 0) IAndeSwapCallee(to).andeSwapCall(msg.sender, amount0Out, amount1Out, data);
            
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        
        require(amount0In > 0 || amount1In > 0, "AndeSwapPair: INSUFFICIENT_INPUT_AMOUNT");
        
        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * 1000000, "AndeSwapPair: K");
        }
        
        _update(balance0, balance1, _reserve0, _reserve1);
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev Skims excess tokens
     * @param to The address to send excess tokens to
     * @return amount0 The amount of token0 skimmed
     * @return amount1 The amount of token1 skimmed
     */
    function skim(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        address _token0 = token0;
        address _token1 = token1;
        
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        
        amount0 = balance0 - _reserve0;
        amount1 = balance1 - _reserve1;
        
        if (amount0 > 0) _safeTransfer(_token0, to, amount0);
        if (amount1 > 0) _safeTransfer(_token1, to, amount1);
    }

    /**
     * @dev Syncs reserves with current balances
     */
    function sync() external nonReentrant {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    /**
     * @dev Updates reserves and cumulative prices
     */
    function _update(
        uint256 balance0,
        uint256 balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "AndeSwapPair: OVERFLOW");
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        
        if (timeElapsed > 0 && _reserve0 > 0 && _reserve1 > 0) {
            price0CumulativeLast += uint256(UQ112x112.uqdiv(UQ112x112.encode(_reserve1), _reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.uqdiv(UQ112x112.encode(_reserve0), _reserve1)) * timeElapsed;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }

    // ERC20 functions
    
    /**
     * @dev Returns the total supply of LP tokens
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the nonce for an address (IERC20Permit)
     */
    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Returns the domain separator (IERC20Permit)
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    /**
     * @dev Transfers LP tokens
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return bool Whether the transfer succeeded
     */
    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Transfers LP tokens from one address to another
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount to transfer
     * @return bool Whether the transfer succeeded
     */
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "AndeSwapPair: ERC20: transfer amount exceeds allowance");
        
        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);
        
        return true;
    }

    /**
     * @dev Approves spending of LP tokens
     * @param spender The spender address
     * @param amount The amount to approve
     * @return bool Whether the approval succeeded
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Internal transfer function
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "AndeSwapPair: ERC20: transfer from the zero address");
        require(to != address(0), "AndeSwapPair: ERC20: transfer to the zero address");
        
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "AndeSwapPair: ERC20: transfer amount exceeds balance");
        
        balanceOf[from] = fromBalance - amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal mint function
     */
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "AndeSwapPair: ERC20: mint to the zero address");
        
        _totalSupply += amount;
        balanceOf[to] += amount;
        
        emit Transfer(address(0), to, amount);
    }

    /**
     * @dev Internal burn function
     */
    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "AndeSwapPair: ERC20: burn from the zero address");
        
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "AndeSwapPair: ERC20: burn amount exceeds balance");
        
        balanceOf[from] = fromBalance - amount;
        _totalSupply -= amount;
        
        emit Transfer(from, address(0), amount);
    }

    /**
     * @dev Internal approve function
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "AndeSwapPair: ERC20: approve from the zero address");
        require(spender != address(0), "AndeSwapPair: ERC20: approve to the zero address");
        
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // EIP-2612 permit function
    
    /**
     * @dev Approves spending of LP tokens via signature
     * @param owner The token owner
     * @param spender The spender address
     * @param value The amount to approve
     * @param deadline The deadline for the permit
     * @param v The v signature parameter
     * @param r The r signature parameter
     * @param s The s signature parameter
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(block.timestamp <= deadline, "AndeSwapPair: EXPIRED");
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        _nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "AndeSwapPair: INVALID_SIGNATURE");
        
        _approve(owner, spender, value);
    }



    /**
     * @dev Safely transfers tokens
     */
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "AndeSwapPair: TRANSFER_FAILED");
    }

    /**
     * @dev Returns the current price of token0 in terms of token1
     * @return price The price of token0
     */
    function price0() external view returns (uint256 price) {
        if (reserve0 > 0) {
            price = (uint256(reserve1) * 1e18) / reserve0;
        }
    }

    /**
     * @dev Returns the current price of token1 in terms of token0
     * @return price The price of token1
     */
    function price1() external view returns (uint256 price) {
        if (reserve1 > 0) {
            price = (uint256(reserve0) * 1e18) / reserve1;
        }
    }

    /**
     * @dev Calculates the amount out for a given amount in
     * @param amountIn The input amount
     * @param tokenIn The input token address
     * @return amountOut The output amount
     */
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        
        if (tokenIn == token0) {
            amountOut = AndeSwapLibrary.getAmountOut(amountIn, _reserve0, _reserve1);
        } else {
            amountOut = AndeSwapLibrary.getAmountOut(amountIn, _reserve1, _reserve0);
        }
    }

    /**
     * @dev Calculates the amount in for a given amount out
     * @param amountOut The output amount
     * @param tokenOut The output token address
     * @return amountIn The input amount
     */
    function getAmountIn(uint256 amountOut, address tokenOut) external view returns (uint256 amountIn) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        
        if (tokenOut == token0) {
            amountIn = AndeSwapLibrary.getAmountIn(amountOut, _reserve1, _reserve0);
        } else {
            amountIn = AndeSwapLibrary.getAmountIn(amountOut, _reserve0, _reserve1);
        }
    }
}

/**
 * @title IAndeSwapCallee
 * @dev Interface for flash loan callbacks
 */
interface IAndeSwapCallee {
    function andeSwapCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/**
 * @title UQ112x112
 * @dev Fixed point math library for price calculations
 */
library UQ112x112 {
    uint224 constant Q112 = 2**112;
    
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
    }
    
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}