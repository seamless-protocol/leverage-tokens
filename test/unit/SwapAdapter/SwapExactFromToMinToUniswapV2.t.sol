// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

contract SwapExactFromToMinToUniswapV2Test is SwapAdapterBaseTest {
    MockERC20 public fromToken = new MockERC20();
    MockERC20 public toToken = new MockERC20();

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_SwapExactFromToMinToUniV2(uint256 fromAmount, uint256 minToAmount) public {
        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromeFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(mockUniswapRouter02)
            })
        });

        MockUniswapRouter02.MockSwap memory mockSwap = MockUniswapRouter02.MockSwap({
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: fromAmount,
            toAmount: minToAmount,
            encodedPath: keccak256(abi.encode(swapContext.path)),
            isExecuted: false
        });
        mockUniswapRouter02.mockNextUniswapV2Swap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToUniV2` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToUniV2`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.exposed_swapExactFromToMinToUniV2(fromAmount, minToAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }
}
