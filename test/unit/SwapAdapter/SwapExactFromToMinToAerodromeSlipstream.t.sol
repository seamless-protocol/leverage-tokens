// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeSlipstreamRouter} from "test/unit/mock/MockAerodromeSlipstreamRouter.sol";

contract SwapExactFromToMinToAerodromeSlipstreamTest is SwapAdapterBaseTest {
    function test_SwapExactFromToMinToAerodromeSlipstream_SingleHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

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

        MockAerodromeSlipstreamRouter.MockSwapSingleHop memory mockSwap = MockAerodromeSlipstreamRouter
            .MockSwapSingleHop({
            fromToken: address(fromToken),
            toToken: address(toToken),
            fromAmount: fromAmount,
            toAmount: minToAmount,
            tickSpacing: tickSpacing[0],
            sqrtPriceLimitX96: 0,
            isExecuted: false
        });
        mockAerodromeSlipstreamRouter.mockNextSingleHopSwap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToAerodromeSlipstream` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodromeSlipstream`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount =
            swapAdapter.exposed_swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeSlipstreamRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_SwapExactFromToMinToAerodromeSlipstream_MultiHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        int24[] memory tickSpacing = new int24[](2);
        tickSpacing[0] = 500;
        tickSpacing[1] = 300;

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

        MockAerodromeSlipstreamRouter.MockSwapMultiHop memory mockSwap = MockAerodromeSlipstreamRouter.MockSwapMultiHop({
            encodedPath: keccak256(swapAdapter.exposed_encodeAerodromeSlipstreamPath(path, tickSpacing, false)),
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: fromAmount,
            toAmount: minToAmount,
            isExecuted: false
        });

        mockAerodromeSlipstreamRouter.mockNextMultiHopSwap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToAerodromeSlipstream` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodromeSlipstream`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount =
            swapAdapter.exposed_swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeSlipstreamRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_SwapExactFromToMinToAerodromeSlipstream_InvalidNumTicks() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

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
        swapAdapter.exposed_swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);
    }

    function _mock_SwapExactFromToMinToAerodromeSlipstream(
        address[] memory path,
        int24[] memory tickSpacing,
        uint256 fromAmount,
        uint256 minToAmount,
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
                encodedPath: keccak256(swapAdapter.exposed_encodeAerodromeSlipstreamPath(path, tickSpacing, false)),
                fromToken: IERC20(path[0]),
                toToken: IERC20(path[path.length - 1]),
                fromAmount: fromAmount,
                toAmount: minToAmount,
                isExecuted: false
            });
            mockAerodromeSlipstreamRouter.mockNextMultiHopSwap(mockSwap);
        } else {
            MockAerodromeSlipstreamRouter.MockSwapSingleHop memory mockSwap = MockAerodromeSlipstreamRouter
                .MockSwapSingleHop({
                fromToken: path[0],
                toToken: path[path.length - 1],
                fromAmount: fromAmount,
                toAmount: minToAmount,
                tickSpacing: tickSpacing[0],
                sqrtPriceLimitX96: 0,
                isExecuted: false
            });
            mockAerodromeSlipstreamRouter.mockNextSingleHopSwap(mockSwap);
        }

        return swapContext;
    }
}
