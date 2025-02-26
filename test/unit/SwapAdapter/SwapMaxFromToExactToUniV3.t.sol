// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockUniswapRouter02} from "test/unit/mock/MockUniswapRouter02.sol";

//  Inherited in `SwapMaxFromToExactTo.t.sol` tests
abstract contract SwapMaxFromToExactToUniV3Test is SwapAdapterBaseTest {
    function test_SwapMaxFromToExactToUniV3_SingleHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToUniV3(path, fees, toAmount, maxFromAmount, false);

        // `SwapAdapter._swapMaxFromToExactToUniswapV3` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToUniswapV3`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToUniV3(toAmount, maxFromAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToUniV3_MultiHop() public {
        uint256 toAmount = 5 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 500;
        fees[1] = 300;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToUniV3(path, fees, toAmount, maxFromAmount, true);

        // `SwapAdapter._swapMaxFromToExactToUniswapV3` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToUniswapV3`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToUniV3(toAmount, maxFromAmount, swapContext);

        // Uniswap receives the fromToken
        assertEq(fromToken.balanceOf(address(mockUniswapRouter02)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToUniV3_InvalidNumFees() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
            path: path,
            encodedPath: _encodeUniswapV3Path(path, fees, true),
            fees: fees,
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(0),
                aerodromeFactory: address(0),
                aerodromeSlipstreamRouter: address(mockAerodromeSlipstreamRouter),
                uniswapRouter02: address(0)
            })
        });

        vm.expectRevert(ISwapAdapter.InvalidNumFees.selector);
        swapAdapter.exposed_swapMaxFromToExactToUniV3(toAmount, maxFromAmount, swapContext);
    }

    function _mock_SwapMaxFromToExactToUniV3(
        address[] memory path,
        uint24[] memory fees,
        uint256 toAmount,
        uint256 maxFromAmount,
        bool isMultiHop
    ) internal returns (ISwapAdapter.SwapContext memory swapContext) {
        swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.UNISWAP_V3,
            path: path,
            encodedPath: _encodeUniswapV3Path(path, fees, true),
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
                encodedPath: keccak256(_encodeUniswapV3Path(path, fees, true)),
                fromToken: IERC20(path[0]),
                toToken: IERC20(path[path.length - 1]),
                fromAmount: maxFromAmount,
                toAmount: toAmount,
                isExecuted: false
            });
            mockUniswapRouter02.mockNextUniswapV3MultiHopSwap(mockSwap);
        } else {
            MockUniswapRouter02.MockV3SingleHopSwap memory mockSwap = MockUniswapRouter02.MockV3SingleHopSwap({
                fromToken: path[0],
                toToken: path[path.length - 1],
                fromAmount: maxFromAmount,
                toAmount: toAmount,
                fee: fees[0],
                sqrtPriceLimitX96: 0,
                isExecuted: false
            });
            mockUniswapRouter02.mockNextUniswapV3SingleHopSwap(mockSwap);
        }

        return swapContext;
    }
}
