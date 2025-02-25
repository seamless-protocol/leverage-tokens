// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IAerodromeRouter} from "src/interfaces/IAerodromeRouter.sol";
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeRouter} from "test/unit/mock/MockAerodromeRouter.sol";

contract SwapExactFromToMinToAerodromeV2Test is SwapAdapterBaseTest {
    address public aerodromeFactory = makeAddr("aerodromeFactory");

    function test_SwapExactFromToMinToAerodrome_SingleHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(mockAerodromeRouter),
                aerodromeFactory: aerodromeFactory,
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(0)
            })
        });

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route(address(fromToken), address(toToken), false, aerodromeFactory);
        MockAerodromeRouter.MockSwap memory mockSwap = MockAerodromeRouter.MockSwap({
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: fromAmount,
            toAmount: minToAmount,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToAerodrome` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodrome`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.exposed_swapExactFromToMinToAerodrome(fromAmount, minToAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_SwapExactFromToMinToAerodrome_MultiHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            path: path,
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(mockAerodromeRouter),
                aerodromeFactory: aerodromeFactory,
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(0)
            })
        });

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](2);
        routes[0] = IAerodromeRouter.Route(path[0], path[1], false, aerodromeFactory);
        routes[1] = IAerodromeRouter.Route(path[1], path[2], false, aerodromeFactory);

        MockAerodromeRouter.MockSwap memory mockSwap = MockAerodromeRouter.MockSwap({
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: fromAmount,
            toAmount: minToAmount,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap);

        // `SwapAdapter._swapExactFromToMinToAerodrome` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapExactFromToMinTo` does which is the external function that calls
        // `_swapExactFromToMinToAerodrome`
        deal(address(fromToken), address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.exposed_swapExactFromToMinToAerodrome(fromAmount, minToAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }
}
