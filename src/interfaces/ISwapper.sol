// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategy} from "./IStrategy.sol";

interface ISwapper {
    enum Provider {
        LiFi
    }

    /// @notice Error thrown when an invalid provider is used
    error InvalidProvider();

    /// @notice Error thrown when a swap uses a low-level call and fails
    error SwapFailed();

    /// @notice Error thrown when the return amount is less than the minimum expected return amount
    error SlippageTooHigh(uint256 actualReturnAmount, uint256 minExpectedReturnAmount);

    /// @notice Swap tokens using a swap provider
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param fromAmount Amount of tokens to swap
    /// @param minToAmount Minimum expected amount of tokens to receive
    /// @param providerSwapData Encoded swap data to use for the swap using the provider
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata providerSwapData
    ) external returns (uint256 toAmount);
}
