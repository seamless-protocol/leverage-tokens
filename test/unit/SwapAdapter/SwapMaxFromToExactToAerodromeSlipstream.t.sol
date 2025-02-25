// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeSlipstreamRouter} from "test/unit/mock/MockAerodromeSlipstreamRouter.sol";

//  Inherited in `SwapMaxFromToExactTo.t.sol` tests
abstract contract SwapMaxFromToExactToAerodromeSlipstreamTest is SwapAdapterBaseTest {
    function test_SwapMaxFromToExactToAerodromeSlipstream_SingleHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToAerodromeSlipstream(path, tickSpacing, toAmount, maxFromAmount, false);

        // `SwapAdapter._swapExactFromToMinToAerodromeSlipstream` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodromeSlipstream`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount =
            swapAdapter.exposed_swapMaxFromToExactToAerodromeSlipstream(toAmount, maxFromAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeSlipstreamRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToAerodromeSlipstream_MultiHop() public {
        uint256 toAmount = 5 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        int24[] memory tickSpacing = new int24[](2);
        tickSpacing[0] = 500;
        tickSpacing[1] = 300;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToAerodromeSlipstream(path, tickSpacing, toAmount, maxFromAmount, true);

        // `SwapAdapter._swapExactFromToMinToAerodromeSlipstream` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodromeSlipstream`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount =
            swapAdapter.exposed_swapMaxFromToExactToAerodromeSlipstream(toAmount, maxFromAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeSlipstreamRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToAerodromeSlipstream_InvalidNumTicks() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 500;

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
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

        vm.expectRevert(ISwapAdapter.InvalidNumTicks.selector);
        swapAdapter.exposed_swapMaxFromToExactToAerodromeSlipstream(toAmount, maxFromAmount, swapContext);
    }

    function _mock_SwapMaxFromToExactToAerodromeSlipstream(
        address[] memory path,
        int24[] memory tickSpacing,
        uint256 toAmount,
        uint256 maxFromAmount,
        bool isMultiHop
    ) internal returns (ISwapAdapter.SwapContext memory swapContext) {
        swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME_SLIPSTREAM,
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

        if (isMultiHop) {
            MockAerodromeSlipstreamRouter.MockSwapMultiHop memory mockSwap = MockAerodromeSlipstreamRouter
                .MockSwapMultiHop({
                encodedPath: keccak256(swapAdapter.exposed_encodeAerodromeSlipstreamPath(path, tickSpacing, true)),
                fromToken: IERC20(path[0]),
                toToken: IERC20(path[path.length - 1]),
                fromAmount: maxFromAmount,
                toAmount: toAmount,
                isExecuted: false
            });
            mockAerodromeSlipstreamRouter.mockNextMultiHopSwap(mockSwap);
        } else {
            MockAerodromeSlipstreamRouter.MockSwapSingleHop memory mockSwap = MockAerodromeSlipstreamRouter
                .MockSwapSingleHop({
                fromToken: path[0],
                toToken: path[path.length - 1],
                fromAmount: maxFromAmount,
                toAmount: toAmount,
                tickSpacing: tickSpacing[0],
                sqrtPriceLimitX96: 0,
                isExecuted: false
            });
            mockAerodromeSlipstreamRouter.mockNextSingleHopSwap(mockSwap);
        }

        return swapContext;
    }
}
