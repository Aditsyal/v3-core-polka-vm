// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './libraries/FullMath.sol';
import './libraries/FixedPoint128.sol';
import './libraries/TransferHelper.sol';
import './libraries/LowGasSafeMath.sol';
import './interfaces/callback/IUniswapV3FlashCallback.sol';

library FlashLoanProvider {
    using LowGasSafeMath for uint256;

    struct FlashParams {
        address token0;
        address token1;
        uint24 fee;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint128 protocolFeeToken0;
        uint128 protocolFeeToken1;
        uint8 feeProtocol;
    }

    function executeFlash(
        FlashParams storage params,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external returns (uint256 newFeeGrowthGlobal0X128, uint256 newFeeGrowthGlobal1X128, uint128 newProtocolFeeToken0, uint128 newProtocolFeeToken1) {
        require(params.liquidity > 0, 'L');

        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, params.fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, params.fee, 1e6);
        
        uint256 balance0Before = getTokenBalance(params.token0);
        uint256 balance1Before = getTokenBalance(params.token1);

        if (amount0 > 0) TransferHelper.safeTransfer(params.token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(params.token1, recipient, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

        uint256 balance0After = getTokenBalance(params.token0);
        uint256 balance1After = getTokenBalance(params.token1);

        require(balance0Before.add(fee0) <= balance0After, 'F0');
        require(balance1Before.add(fee1) <= balance1After, 'F1');

        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;

        newFeeGrowthGlobal0X128 = params.feeGrowthGlobal0X128;
        newFeeGrowthGlobal1X128 = params.feeGrowthGlobal1X128;
        newProtocolFeeToken0 = params.protocolFeeToken0;
        newProtocolFeeToken1 = params.protocolFeeToken1;

        if (paid0 > 0) {
            uint8 feeProtocol0 = params.feeProtocol % 16;
            uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 / feeProtocol0;
            if (uint128(fees0) > 0) newProtocolFeeToken0 += uint128(fees0);
            newFeeGrowthGlobal0X128 += FullMath.mulDiv(paid0 - fees0, FixedPoint128.Q128, params.liquidity);
        }
        if (paid1 > 0) {
            uint8 feeProtocol1 = params.feeProtocol >> 4;
            uint256 fees1 = feeProtocol1 == 0 ? 0 : paid1 / feeProtocol1;
            if (uint128(fees1) > 0) newProtocolFeeToken1 += uint128(fees1);
            newFeeGrowthGlobal1X128 += FullMath.mulDiv(paid1 - fees1, FixedPoint128.Q128, params.liquidity);
        }
    }

    function getTokenBalance(address token) private view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }
} 