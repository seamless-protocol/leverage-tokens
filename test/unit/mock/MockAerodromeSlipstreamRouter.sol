// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IAerodromeSlipstreamRouter} from "src/interfaces/IAerodromeSlipstreamRouter.sol";

contract MockAerodromeSlipstreamRouter is Test {
    struct MockExactInputSingleSwap {
        address fromToken;
        address toToken;
        uint256 fromAmount;
        uint256 toAmount;
        int24 tickSpacing;
        uint160 sqrtPriceLimitX96;
        bool isExecuted;
    }

    MockExactInputSingleSwap[] public exactInputSingleSwaps;

    function mockNextExactInputSingleSwap(MockExactInputSingleSwap memory swap) public {
        exactInputSingleSwaps.push(swap);
    }

    function exactInputSingle(IAerodromeSlipstreamRouter.ExactInputSingleParams memory params)
        external
        payable
        returns (uint256 amountOut)
    {
        for (uint256 i = 0; i < exactInputSingleSwaps.length; i++) {
            MockExactInputSingleSwap memory swap = exactInputSingleSwaps[i];
            if (
                !swap.isExecuted && swap.fromToken == params.tokenIn && swap.toToken == params.tokenOut
                    && swap.tickSpacing == params.tickSpacing && swap.sqrtPriceLimitX96 == params.sqrtPriceLimitX96
            ) {
                require(swap.toAmount >= params.amountOutMinimum, "MockUniswapRouter02: INSUFFICIENT_OUTPUT_AMOUNT");

                // Transfer in the fromToken
                IERC20(swap.fromToken).transferFrom(msg.sender, address(this), params.amountIn);

                // Transfer out the toToken
                deal(address(swap.toToken), address(this), swap.toAmount);
                IERC20(swap.toToken).transfer(params.recipient, swap.toAmount);

                exactInputSingleSwaps[i].isExecuted = true;
                return swap.toAmount;
            }
        }

        revert("MockUniswapRouter02: No mocked v2 swap set");
    }
}
