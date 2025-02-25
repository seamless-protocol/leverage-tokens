// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

contract SwapExactFromToMinToUniswapV3Test is SwapAdapterBaseTest {
    function test_SwapExactFromToMinToUniV3_SingleHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapExactFromToMinToUniV3(path, fees, fromAmount, minToAmount, false);

        // `SwapAdapter._swapExactFromToMinToUniV2` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToUniV2`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.exposed_swapExactFromToMinToUniV3(fromAmount, minToAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_SwapExactFromToMinToUniV3_MultiHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 500;
        fees[1] = 300;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapExactFromToMinToUniV3(path, fees, fromAmount, minToAmount, true);

        // `SwapAdapter._swapExactFromToMinToUniV3` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToUniV3`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.exposed_swapExactFromToMinToUniV3(fromAmount, minToAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_SwapExactFromToMinToUniV3_InvalidNumFees() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromeFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(mockUniswapRouter02)
            })
        });

        vm.expectRevert(ISwapAdapter.InvalidNumFees.selector);
        swapAdapter.exposed_swapExactFromToMinToUniV3(fromAmount, minToAmount, swapContext);
    }

    function _mock_SwapExactFromToMinToUniV3(
        address[] memory path,
        uint24[] memory fees,
        uint256 fromAmount,
        uint256 minToAmount,
        bool isMultiHop
    ) internal returns (ISwapAdapter.SwapContext memory swapContext) {
        swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            path: path,
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromeFactory: address(0),
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(mockUniswapRouter02)
            })
        });

        if (isMultiHop) {
            MockUniswapRouter02.MockV3MultiHopSwap memory mockSwap = MockUniswapRouter02.MockV3MultiHopSwap({
                encodedPath: keccak256(swapAdapter.exposed_encodeUniswapV3Path(path, fees, false)),
                fromToken: IERC20(path[0]),
                toToken: IERC20(path[path.length - 1]),
                fromAmount: fromAmount,
                toAmount: minToAmount,
                isExecuted: false
            });
            mockUniswapRouter02.mockNextUniswapV3MultiHopSwap(mockSwap);
        } else {
            MockUniswapRouter02.MockV3SingleHopSwap memory mockSwap = MockUniswapRouter02.MockV3SingleHopSwap({
                fromToken: path[0],
                toToken: path[path.length - 1],
                fromAmount: fromAmount,
                toAmount: minToAmount,
                fee: fees[0],
                sqrtPriceLimitX96: 0,
                isExecuted: false
            });
            mockUniswapRouter02.mockNextUniswapV3SingleHopSwap(mockSwap);
        }

        return swapContext;
    }
}
