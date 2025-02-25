// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

//  Inherited in `SwapExactFromToMinTo.t.sol` tests
abstract contract SwapExactFromToMinToUniV2Test is SwapAdapterBaseTest {
    function test_SwapExactFromToMinToUniV2_SingleHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToUniV2(path, fromAmount, minToAmount);

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

    function test_SwapExactFromToMinToUniV2_MultiHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToUniV2(path, fromAmount, minToAmount);

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

    function _mock_SwapExactFromToMinToUniV2(address[] memory path, uint256 fromAmount, uint256 minToAmount)
        internal
        returns (ISwapAdapter.SwapContext memory swapContext)
    {
        swapContext = ISwapAdapter.SwapContext({
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

        MockUniswapRouter02.MockV2Swap memory mockSwap = MockUniswapRouter02.MockV2Swap({
            fromToken: IERC20(path[0]),
            toToken: IERC20(path[path.length - 1]),
            fromAmount: fromAmount,
            toAmount: minToAmount,
            encodedPath: keccak256(abi.encode(path)),
            isExecuted: false
        });
        mockUniswapRouter02.mockNextUniswapV2Swap(mockSwap);

        return swapContext;
    }
}
