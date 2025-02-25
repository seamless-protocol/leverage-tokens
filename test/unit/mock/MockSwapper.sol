// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";

contract MockSwapper is Test {
    struct MockedSwap {
        IERC20 toToken;
        uint256 toAmount;
        bool isExecuted;
    }

    mapping(IERC20 fromToken => MockedSwap[]) public nextSwapToAmount;

    function mockNextSwap(IERC20 fromToken, IERC20 toToken, uint256 mockedToAmount) external {
        nextSwapToAmount[fromToken].push(MockedSwap({toToken: toToken, toAmount: mockedToAmount, isExecuted: false}));
    }

    function swapExactFromToMinTo(
        IERC20 fromToken,
        uint256, /* toAmount */
        uint256 maxFromAmount,
        ISwapAdapter.SwapContext memory /* swapContext */
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), maxFromAmount);

        MockedSwap[] storage mockedSwaps = nextSwapToAmount[fromToken];
        for (uint256 i = 0; i < mockedSwaps.length; i++) {
            MockedSwap memory mockedSwap = mockedSwaps[i];

            if (!mockedSwap.isExecuted) {
                // Deal the toToken to the sender
                deal(
                    address(mockedSwap.toToken),
                    msg.sender,
                    mockedSwap.toToken.balanceOf(msg.sender) + mockedSwap.toAmount
                );

                // Set the swap as executed
                mockedSwaps[i].isExecuted = true;

                return mockedSwap.toAmount;
            }
        }

        // If no mocked swap is set, revert by default
        revert("MockSwapper: No mocked swap set");
    }
}
