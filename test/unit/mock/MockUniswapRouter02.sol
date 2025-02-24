// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IUniswapSwapRouter02} from "src/interfaces/IUniswapSwapRouter02.sol";

contract MockUniswapRouter02 is Test {
    struct MockV2Swap {
        IERC20 fromToken;
        IERC20 toToken;
        uint256 fromAmount;
        uint256 toAmount;
        bytes32 encodedPath;
        bool isExecuted;
    }

    struct MockV3ExactInputSingleSwap {
        address fromToken;
        address toToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
        bool isExecuted;
    }

    MockV2Swap[] public v2Swaps;

    MockV3ExactInputSingleSwap[] public v3ExactInputSingleSwaps;

    function mockNextUniswapV2Swap(MockV2Swap memory swap) external {
        v2Swaps.push(swap);
    }

    function mockNextUniswapV3ExactInputSingleSwap(MockV3ExactInputSingleSwap memory swap) external {
        v3ExactInputSingleSwaps.push(swap);
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        payable
        returns (uint256 amountOut)
    {
        for (uint256 i = 0; i < v2Swaps.length; i++) {
            MockV2Swap memory swap = v2Swaps[i];
            bytes32 encodedPath = keccak256(abi.encode(path));
            if (!swap.isExecuted && swap.encodedPath == encodedPath) {
                require(swap.toAmount >= amountOutMin, "MockUniswapRouter02: INSUFFICIENT_OUTPUT_AMOUNT");

                // Transfer in the fromToken
                swap.fromToken.transferFrom(msg.sender, address(this), amountIn);

                // Transfer out the toToken
                deal(address(swap.toToken), address(this), swap.toAmount);
                swap.toToken.transfer(to, swap.toAmount);

                v2Swaps[i].isExecuted = true;
                return swap.toAmount;
            }
        }

        revert("MockUniswapRouter02: No mocked v2 swap set");
    }

    function exactInputSingle(IUniswapSwapRouter02.ExactInputSingleParams memory params)
        external
        payable
        returns (uint256 amountOut)
    {
        for (uint256 i = 0; i < v3ExactInputSingleSwaps.length; i++) {
            MockV3ExactInputSingleSwap memory swap = v3ExactInputSingleSwaps[i];
            if (
                !swap.isExecuted && swap.fromToken == params.tokenIn && swap.toToken == params.tokenOut
                    && swap.fee == params.fee && swap.sqrtPriceLimitX96 == params.sqrtPriceLimitX96
            ) {
                require(swap.toAmount >= params.amountOutMinimum, "MockUniswapRouter02: INSUFFICIENT_OUTPUT_AMOUNT");

                // Transfer in the fromToken
                IERC20(swap.fromToken).transferFrom(msg.sender, address(this), params.amountIn);

                // Transfer out the toToken
                deal(address(swap.toToken), address(this), swap.toAmount);
                IERC20(swap.toToken).transfer(params.recipient, swap.toAmount);

                v3ExactInputSingleSwaps[i].isExecuted = true;
                return swap.toAmount;
            }
        }

        revert("MockUniswapRouter02: No mocked v2 swap set");
    }
}
