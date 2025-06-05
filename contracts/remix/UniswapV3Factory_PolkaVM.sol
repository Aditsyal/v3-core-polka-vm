// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IUniswapV3Factory {
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, int24 tickSpacing, address pool);
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);
    function owner() external view returns (address);
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function setOwner(address _owner) external;
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}

contract SimpleAMM {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    
    uint256 public reserve0;
    uint256 public reserve1;
    
    uint256 private locked;
    modifier lock() { require(locked == 0); locked = 1; _; locked = 0; }
    
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to);

    constructor(address _token0, address _token1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external lock {
        require(amount0 > 0 && amount1 > 0);
        require(IERC20(token0).transferFrom(msg.sender, address(this), amount0));
        require(IERC20(token1).transferFrom(msg.sender, address(this), amount1));
        reserve0 += amount0;
        reserve1 += amount1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external lock {
        require(amount0Out > 0 || amount1Out > 0);
        require(amount0Out < reserve0 && amount1Out < reserve1);

        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        if (amount0Out > 0) require(IERC20(token0).transfer(to, amount0Out));
        if (amount1Out > 0) require(IERC20(token1).transfer(to, amount1Out));

        uint256 balance0After = IERC20(token0).balanceOf(address(this));
        uint256 balance1After = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0After > balance0Before - amount0Out ? balance0After - (balance0Before - amount0Out) : 0;
        uint256 amount1In = balance1After > balance1Before - amount1Out ? balance1After - (balance1Before - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0);

        uint256 balance0Adjusted = balance0After * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1After * 1000 - amount1In * 3;
        require(balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * 1000000);

        reserve0 = balance0After;
        reserve1 = balance1After;

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }
}

contract UniswapV3Factory is IUniswapV3Factory {
    address private immutable original;
    address public override owner;
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    modifier noDelegateCall() { require(address(this) == original); _; }

    constructor() {
        original = address(this);
        owner = msg.sender;
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
        feeAmountTickSpacing[10000] = 200;
    }

    function createPool(address tokenA, address tokenB, uint24 fee) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB && tokenA != address(0));
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(feeAmountTickSpacing[fee] != 0 && getPool[token0][token1][fee] == address(0));
        
        pool = address(new SimpleAMM(token0, token1, fee));
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, feeAmountTickSpacing[fee], pool);
    }

    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {
        require(msg.sender == owner && fee < 1000000 && tickSpacing > 0 && tickSpacing < 16384 && feeAmountTickSpacing[fee] == 0);
        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
} 