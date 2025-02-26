// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency Imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

//  Inherited in `SwapMaxFromToExactTo.t.sol` tests
abstract contract SwapMaxFromToExactToUniV2Test is SwapAdapterBaseTest {
    function test_SwapMaxFromToExactToUniV2_SingleHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToUniV2(path, toAmount, maxFromAmount);

        // `SwapAdapter._swapMaxFromToExactToUniV2` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToUniV2`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToUniV2(toAmount, maxFromAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToUniV2_MultiHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToUniV2(path, toAmount, maxFromAmount);

        // `SwapAdapter._swapMaxFromToExactToUniV2` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToUniV2`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToUniV2(toAmount, maxFromAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function _mock_SwapMaxFromToExactToUniV2(address[] memory path, uint256 toAmount, uint256 maxFromAmount)
        internal
        returns (ISwapAdapter.SwapContext memory swapContext)
    {
        swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V2,
            path: path,
            encodedPath: new bytes(0),
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
            fromAmount: maxFromAmount,
            toAmount: toAmount,
            encodedPath: keccak256(abi.encode(path)),
            isExecuted: false
        });
        mockUniswapRouter02.mockNextUniswapV2Swap(mockSwap);

        return swapContext;
    }
}
