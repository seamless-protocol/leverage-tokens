// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwapper is Test {
    struct MockedSwap {
        uint256 toAmount;
        bool isExecuted;
    }

    mapping(IERC20 fromToken => mapping(IERC20 toToken => MockedSwap[])) public nextSwapToAmount;

    function mockNextSwap(IERC20 fromToken, IERC20 toToken, uint256 mockedToAmount) external {
        nextSwapToAmount[fromToken][toToken].push(MockedSwap({toAmount: mockedToAmount, isExecuted: false}));
    }

    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256, /* minToAmount */
        bytes calldata /* providerSwapData */
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), fromAmount);

        MockedSwap[] storage mockedSwaps = nextSwapToAmount[fromToken][toToken];
        for (uint256 i = 0; i < mockedSwaps.length; i++) {
            MockedSwap memory mockedSwap = mockedSwaps[i];

            if (!mockedSwap.isExecuted) {
                // Deal the toToken to the sender
                deal(address(toToken), msg.sender, toToken.balanceOf(msg.sender) + mockedSwap.toAmount);

                // Set the swap as executed
                mockedSwaps[i].isExecuted = true;

                return mockedSwap.toAmount;
            }
        }

        // If no mocked swap is set, revert by default
        revert("MockSwapper: No mocked swap set");
    }
}
