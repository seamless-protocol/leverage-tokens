// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategy} from "./IStrategy.sol";

interface ISwapAdapter {
    enum Exchange {
        AERODROME,
        AERODROME_SLIPSTREAM,
        UNISWAP_V3,
        UNISWAP_V2
    }

    struct ExchangeAddresses {
        address aerodromeRouter;
        address aerodromeFactory;
        address aerodromeSlipstreamRouter;
        address uniswapRouter02;
    }

    struct SwapContext {
        address[] path;
        uint24[] fees;
        int24[] tickSpacing;
        Exchange exchange;
        ExchangeAddresses exchangeAddresses;
    }

    error InvalidNumTicks();

    error InvalidNumFees();

    /// @notice Swap tokens from the fromToken to the toToken using the specified provider
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param toAmount Amount of tokens to receive
    /// @param maxFromAmount Maximum amount of tokens to swap
    /// @param swapContext Swap context to use for the swap (which exchange to use, the route, tick spacing, etc.)
    /// @return fromAmount Amount of tokens swapped
    function swapMaxFromToExactTo(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 toAmount,
        uint256 maxFromAmount,
        SwapContext memory swapContext
    ) external returns (uint256 fromAmount);

    /// @notice Swap tokens from the fromToken to the toToken using the specified provider
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param fromAmount Amount of tokens to swap
    /// @param minToAmount Minimum amount of tokens to receive
    /// @param swapContext Swap context to use for the swap (which exchange to use, the route, tick spacing, etc.)
    /// @return toAmount Amount of tokens received
    function swapExactFromToMinTo(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        SwapContext memory swapContext
    ) external returns (uint256 toAmount);
}
