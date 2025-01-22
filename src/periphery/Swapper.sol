// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IOneInchAggregationExecutor,
    IOneInchAggregationRouterV6,
    OneInchSwapDescription
} from "src/interfaces/IOneInchAggregationRouterV6.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract Swapper is ISwapper {
    IOneInchAggregationRouterV6 public oneInchAggregationRouter;

    constructor(IOneInchAggregationRouterV6 _oneInchAggregationRouter) {
        oneInchAggregationRouter = _oneInchAggregationRouter;
    }

    function swap(Provider provider, IERC20 from, uint256 fromAmount, bytes calldata providerSwapData)
        external
        returns (uint256)
    {
        SafeERC20.safeTransferFrom(from, msg.sender, address(this), fromAmount);

        if (provider == Provider.OneInch) {
            IOneInchAggregationRouterV6 _oneInchAggregationRouter = oneInchAggregationRouter;

            // providerSwapData should include the 1inch executor, description, and the swap tx data, obtained off-chain by the 1inch API
            (IOneInchAggregationExecutor executor, OneInchSwapDescription memory description, bytes memory swapData) =
                abi.decode(providerSwapData, (IOneInchAggregationExecutor, OneInchSwapDescription, bytes));

            from.approve(address(_oneInchAggregationRouter), fromAmount);
            (uint256 toAmount,) = _oneInchAggregationRouter.swap(executor, description, swapData);

            if (toAmount < description.minReturnAmount) {
                revert SlippageTooHigh(toAmount, description.minReturnAmount);
            } else {
                return toAmount;
            }
        } else {
            revert InvalidProvider();
        }
    }
}
