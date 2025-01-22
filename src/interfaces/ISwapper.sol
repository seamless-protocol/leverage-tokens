// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategy} from "./IStrategy.sol";

interface ISwapper {
    enum Provider {
        OneInch
    }

    /// @notice Error thrown when an invalid provider is used
    error InvalidProvider();

    /// @notice Error thrown when the return amount is less than the minimum expected return amount
    error SlippageTooHigh(uint256 actualReturnAmount, uint256 minExpectedReturnAmount);

    /// @notice Swap tokens using a provider
    /// @param provider Provider to use for the swap
    /// @param from Token to swap from
    /// @param to Token to swap to
    /// @param fromAmount Amount of `from` tokens to swap
    /// @param beneficiary Address to receive the swapped tokens
    /// @param minReturnAmount Minimum amount of `to` tokens to receive
    /// @param providerSwapData Swap data to use for the swap using the provider
    function swap(
        Provider provider,
        IERC20 from,
        IERC20 to,
        uint256 fromAmount,
        address payable beneficiary,
        uint256 minReturnAmount,
        bytes calldata providerSwapData
    ) external returns (uint256 toAmount);
}
