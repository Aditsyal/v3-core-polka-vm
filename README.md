# PolkaVM AMM Contracts for Remix IDE

## Overview

This directory contains PolkaVM-compatible AMM contracts optimized for deployment using Remix IDE. The contracts are based on Uniswap V3 but simplified for PolkaVM constraints and size limitations.

## Key Modifications for PolkaVM

### 1. Solidity Version Upgrade
- **From**: `=0.7.6` (original Uniswap V3)
- **To**: `^0.8.0` (PolkaVM compatible)

### 2. Contract Size Optimization
- **Original V3 Pool**: ~35kB (too large for PolkaVM)
- **Simplified AMM Pool**: ~6-8kB (within PolkaVM limits)
- **Factory Contract**: ~8-10kB (optimized)

### 3. Algorithmic Simplification
- **Original**: Concentrated liquidity with complex tick mathematics
- **Simplified**: Constant product AMM (x * y = k) like Uniswap V2
- **Benefits**: Smaller contract size, simpler logic, PolkaVM compatible

### 4. Architecture Changes
- Consolidated all dependencies into single files
- Removed complex libraries (TickMath, Oracle, etc.)
- Embedded pool logic in factory for easier deployment
- Added basic error messages for debugging

## Contract Files

### 1. `UniswapV3Factory_PolkaVM.sol`
**Main factory contract containing:**
- `IUniswapV3Factory` - Factory interface
- `IERC20Minimal` - Minimal ERC20 interface
- `SafeCast` - Safe type casting library
- `NoDelegateCall` - Security base contract
- `SimpleAMM` - Simplified constant product AMM pool
- `UniswapV3Factory` - Main factory implementation

**Key Features:**
- Creates simplified AMM pools instead of V3 concentrated liquidity pools
- Maintains same interface as Uniswap V3 Factory for compatibility
- Implements constant product formula for swaps
- Supports multiple fee tiers (0.05%, 0.3%, 1.0%)

### 2. `TestERC20.sol`
**Simple ERC20 token for testing:**
- Standard ERC20 implementation
- Mint function for testing
- Configurable name, symbol, decimals, and supply

### 3. `DeploymentScript.md`
**Step-by-step deployment guide:**
- Pre-deployment checklist
- Detailed deployment instructions
- Testing procedures
- Troubleshooting tips

### 4. `interaction_script.js`
**JavaScript interaction script for Remix:**
- Automated deployment and testing
- Helper functions for manual operations
- ABI definitions for all contracts
- Console-friendly logging

## Contract Specifications

### UniswapV3Factory
```solidity
contract UniswapV3Factory is IUniswapV3Factory, NoDelegateCall {
    address public owner;
    mapping(uint24 => int24) public feeAmountTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;
    
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function setOwner(address _owner) external;
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
```

### SimpleAMM (Pool Contract)
```solidity
contract SimpleAMM {
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    function addLiquidity(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity);
    function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1);
}
```

## Deployment Instructions

### Quick Start
1. Open Remix IDE (https://remix.ethereum.org)
2. Create new workspace or use existing
3. Upload contract files from this directory
4. Follow steps in `DeploymentScript.md`

### Detailed Steps
1. **Setup Environment**
   - Configure Remix with PolkaVM RPC
   - Ensure you have test tokens for gas

2. **Deploy Contracts**
   ```bash
   # In Remix IDE:
   1. Compile TestERC20.sol
   2. Deploy Token A and Token B
   3. Compile UniswapV3Factory_PolkaVM.sol
   4. Deploy Factory
   5. Create pool via factory.createPool()
   ```

3. **Test Functionality**
   - Add liquidity to pool
   - Execute test swaps
   - Monitor gas costs and transaction success

## Gas Cost Estimates (PolkaVM)

| Operation | Estimated Gas | Notes |
|-----------|---------------|-------|
| Factory Deployment | 2-3M | One-time cost |
| Pool Creation | 1-2M | Per pool pair |
| Add Liquidity | 200-400k | Depends on amounts |
| Remove Liquidity | 150-300k | Depends on amounts |
| Token Swap | 150-300k | Depends on complexity |

## Differences from Uniswap V3

| Feature | Uniswap V3 | PolkaVM AMM |
|---------|------------|-------------|
| Liquidity Model | Concentrated | Constant Product |
| Contract Size | ~35kB | ~6-8kB |
| Complexity | High | Low |
| Tick System | Complex | None |
| Price Oracles | Built-in | Simplified |
| Fee Structure | Multiple | Standard (0.3%) |

## Security Considerations

### Implemented
- ✅ No delegate call protection
- ✅ Reentrancy protection via checks-effects-interactions
- ✅ Safe math operations (Solidity ^0.8.0 built-in)
- ✅ Input validation and error messages

### Not Implemented (for production)
- ⚠️ Admin controls and pausing mechanisms
- ⚠️ Upgradability patterns
- ⚠️ Advanced access controls
- ⚠️ Comprehensive test coverage
- ⚠️ External security audits

## Testing

### Automated Testing
Run the complete test suite using the JavaScript script:
```javascript
// In Remix IDE console
deployAndTest()
```

### Manual Testing
```javascript
// Check pool reserves
checkPoolReserves("0xPoolAddress")

// Check token balance
checkTokenBalance("0xTokenAddress", "0xUserAddress")

// Add liquidity manually
addLiquidityManual("0xPoolAddress", "0xTokenA", "0xTokenB", 1000, 1000)
```

## Troubleshooting

### Common Issues
1. **Contract too large**: Further optimization needed
2. **Out of gas**: Increase gas limit or optimize operations
3. **Insufficient allowance**: Approve tokens before operations
4. **Pool doesn't exist**: Create pool first via factory

### Debug Tips
- Use Remix debugger for transaction analysis
- Check event logs for detailed information
- Verify token approvals before operations
- Monitor gas costs for PolkaVM compatibility

## Production Deployment

### Checklist
- [ ] Security audit completed
- [ ] Gas optimization verified
- [ ] Error handling comprehensive
- [ ] Access controls implemented
- [ ] Monitoring systems ready
- [ ] Documentation complete

### Recommendations
1. Implement proper access controls
2. Add pause/emergency stop functionality
3. Consider upgradability patterns
4. Implement comprehensive testing
5. Set up monitoring and alerting
6. Plan for gas cost optimization

## Support and Contributions

### Issues
Report issues with:
- Contract compilation errors
- Deployment failures
- Gas cost problems
- Functionality bugs

### Improvements
Suggestions for:
- Further size optimization
- Additional features
- Better error handling
- Enhanced security

---

**Note**: These contracts are optimized for PolkaVM deployment via Remix IDE. For production use, additional security measures, testing, and auditing are strongly recommended. 