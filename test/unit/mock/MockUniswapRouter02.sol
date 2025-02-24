// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapRouter02 is Test {
    struct MockSwap {
        IERC20 fromToken;
        IERC20 toToken;
        uint256 fromAmount;
        uint256 toAmount;
        bytes32 encodedPath;
        bool isExecuted;
    }

    MockSwap[] public v2Swaps;

    function mockNextUniswapV2Swap(MockSwap memory swap) external {
        v2Swaps.push(swap);
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        payable
        returns (uint256 amountOut)
    {
        for (uint256 i = 0; i < v2Swaps.length; i++) {
            MockSwap memory swap = v2Swaps[i];
            bytes32 encodedPath = keccak256(abi.encode(path));
            if (!swap.isExecuted && swap.encodedPath == encodedPath) {
                require(swap.toAmount >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

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
}
