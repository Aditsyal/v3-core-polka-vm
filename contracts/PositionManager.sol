// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './libraries/Position.sol';
import './libraries/Tick.sol';
import './libraries/TickBitmap.sol';
import './libraries/LiquidityMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/TickMath.sol';
import './libraries/SafeCast.sol';
import './libraries/TransferHelper.sol';
import './interfaces/callback/IUniswapV3MintCallback.sol';

library PositionManager {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using SafeCast for uint256;

    struct PoolState {
        uint128 liquidity;
        mapping(int24 => Tick.Info) ticks;
        mapping(int16 => uint256) tickBitmap;
        mapping(bytes32 => Position.Info) positions;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        int24 tickSpacing;
        uint128 maxLiquidityPerTick;
    }

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
        int24 currentTick;
        uint32 time;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
    }

    function modifyPosition(
        PoolState storage state,
        ModifyPositionParams memory params
    ) external returns (Position.Info storage position, int256 amount0, int256 amount1) {
        position = updatePosition(state, params);

        if (params.liquidityDelta != 0) {
            if (params.currentTick < params.tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (params.currentTick < params.tickUpper) {
                uint128 liquidityBefore = state.liquidity;

                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.currentTick),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.currentTick),
                    params.liquidityDelta
                );

                state.liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    function updatePosition(
        PoolState storage state,
        ModifyPositionParams memory params
    ) internal returns (Position.Info storage position) {
        position = state.positions.get(params.owner, params.tickLower, params.tickUpper);

        bool flippedLower;
        bool flippedUpper;
        if (params.liquidityDelta != 0) {
            flippedLower = state.ticks.update(
                params.tickLower,
                params.currentTick,
                params.liquidityDelta,
                state.feeGrowthGlobal0X128,
                state.feeGrowthGlobal1X128,
                params.secondsPerLiquidityCumulativeX128,
                params.tickCumulative,
                params.time,
                false,
                state.maxLiquidityPerTick
            );
            flippedUpper = state.ticks.update(
                params.tickUpper,
                params.currentTick,
                params.liquidityDelta,
                state.feeGrowthGlobal0X128,
                state.feeGrowthGlobal1X128,
                params.secondsPerLiquidityCumulativeX128,
                params.tickCumulative,
                params.time,
                true,
                state.maxLiquidityPerTick
            );

            if (flippedLower) {
                state.tickBitmap.flipTick(params.tickLower, state.tickSpacing);
            }
            if (flippedUpper) {
                state.tickBitmap.flipTick(params.tickUpper, state.tickSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            state.ticks.getFeeGrowthInside(
                params.tickLower, 
                params.tickUpper, 
                params.currentTick, 
                state.feeGrowthGlobal0X128, 
                state.feeGrowthGlobal1X128
            );

        position.update(params.liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        if (params.liquidityDelta < 0) {
            if (flippedLower) {
                state.ticks.clear(params.tickLower);
            }
            if (flippedUpper) {
                state.ticks.clear(params.tickUpper);
            }
        }
    }
} 