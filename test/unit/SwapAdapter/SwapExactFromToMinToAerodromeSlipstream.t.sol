// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeSlipstreamRouter} from "test/unit/mock/MockAerodromeSlipstreamRouter.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

contract SwapExactFromToMinToAerodromeSlipstreamTest is SwapAdapterBaseTest {
    MockERC20 public fromToken = new MockERC20();
    MockERC20 public toToken = new MockERC20();

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_SwapExactFromToMinToAerodromeSlipstream(uint256 fromAmount, uint256 minToAmount) public {
        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            path: path,
            fees: new uint24[](0),
            tickSpacing: tickSpacing,
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromeFactory: address(0),
                aerodromeSlipstreamRouter: address(mockAerodromeSlipstreamRouter),
                uniswapRouter02: address(0)
            })
        });

        MockAerodromeSlipstreamRouter.MockExactInputSingleSwap memory mockSwap = MockAerodromeSlipstreamRouter
            .MockExactInputSingleSwap({
            fromToken: address(fromToken),
            toToken: address(toToken),
            fromAmount: fromAmount,
            toAmount: minToAmount,
            tickSpacing: tickSpacing[0],
            sqrtPriceLimitX96: 0,
            isExecuted: false
        });
        mockAerodromeSlipstreamRouter.mockNextExactInputSingleSwap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToAerodromeSlipstream` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodromeSlipstream`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount =
            swapAdapter.exposed_swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeSlipstreamRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }
}
