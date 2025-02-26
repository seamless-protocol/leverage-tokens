// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IAerodromeRouter} from "src/interfaces/periphery/IAerodromeRouter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeRouter} from "test/unit/mock/MockAerodromeRouter.sol";

//  Inherited in `SwapMaxFromToExactTo.t.sol` tests
abstract contract SwapMaxFromToExactToAerodromeTest is SwapAdapterBaseTest {
    address public aerodromeFactory = makeAddr("aerodromeFactory");

    function test_SwapMaxFromToExactToAerodrome_SingleHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToAerodrome(path, toAmount, maxFromAmount);

        // `SwapAdapter._swapMaxFromToExactToAerodrome` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToAerodrome`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToAerodrome(toAmount, maxFromAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToAerodrome_MultiHop() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](3);
        path[0] = address(fromToken);
        path[1] = makeAddr("additional hop");
        path[2] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToAerodrome(path, toAmount, maxFromAmount);

        // `SwapAdapter._swapMaxFromToExactToAerodrome` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToAerodrome`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToAerodrome(toAmount, maxFromAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeRouter)), fromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_SwapMaxFromToExactToAerodrome_SurplusToToken() public {
        uint256 toAmount = 10 ether;
        uint256 surplusToAmount = 1 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            path: path,
            encodedPath: new bytes(0),
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
            fromAmount: maxFromAmount,
            toAmount: toAmount + surplusToAmount,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap);

        // Mock the additional expected swap of the surplus toToken
        routes[0] = IAerodromeRouter.Route(path[1], path[0], false, aerodromeFactory);
        MockAerodromeRouter.MockSwap memory mockSwap2 = MockAerodromeRouter.MockSwap({
            fromToken: toToken,
            toToken: fromToken,
            fromAmount: surplusToAmount,
            toAmount: 0.5 ether,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap2);

        // `SwapAdapter._swapMaxFromToExactToAerodrome` does not transfer in the fromToken,
        // `SwapAdapterHarness.swapMaxFromToExactTo` does which is the external function that calls
        // `_swapMaxFromToExactToAerodrome`
        deal(address(fromToken), address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.exposed_swapMaxFromToExactToAerodrome(toAmount, maxFromAmount, swapContext);

        // Aerodrome receives the fromToken
        assertEq(fromToken.balanceOf(address(mockAerodromeRouter)), maxFromAmount);
        // We receive the toToken
        assertEq(toToken.balanceOf(address(this)), toAmount);
        // We receive the surplus fromToken
        assertEq(fromToken.balanceOf(address(this)), mockSwap2.toAmount);
        // The fromAmount should be less than the maxFromAmount by the surplus received from the second swap
        assertEq(fromAmount, maxFromAmount - mockSwap2.toAmount);
    }

    function _mock_SwapMaxFromToExactToAerodrome(address[] memory path, uint256 toAmount, uint256 maxFromAmount)
        internal
        returns (ISwapAdapter.SwapContext memory swapContext)
    {
        swapContext = ISwapAdapter.SwapContext({
            exchange: ISwapAdapter.Exchange.AERODROME,
            path: path,
            encodedPath: new bytes(0),
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            exchangeAddresses: ISwapAdapter.ExchangeAddresses({
                aerodromeRouter: address(mockAerodromeRouter),
                aerodromeFactory: aerodromeFactory,
                aerodromeSlipstreamRouter: address(0),
                uniswapRouter02: address(0)
            })
        });

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](path.length - 1);
        for (uint256 i = 0; i < path.length - 1; i++) {
            routes[i] = IAerodromeRouter.Route(path[i], path[i + 1], false, aerodromeFactory);
        }

        MockAerodromeRouter.MockSwap memory mockSwap = MockAerodromeRouter.MockSwap({
            fromToken: fromToken,
            toToken: toToken,
            fromAmount: maxFromAmount,
            toAmount: toAmount,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap);

        return swapContext;
    }
}
