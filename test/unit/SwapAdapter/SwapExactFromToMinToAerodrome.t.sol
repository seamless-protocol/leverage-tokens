// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IAerodromeRouter} from "src/interfaces/IAerodromeRouter.sol";
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";
import {MockAerodromeRouter} from "test/unit/mock/MockAerodromeRouter.sol";

//  Inherited in `SwapExactFromToMinTo.t.sol` tests
abstract contract SwapExactFromToMinToAerodromeTest is SwapAdapterBaseTest {
    address public aerodromeFactory = makeAddr("aerodromeFactory");

    function test_SwapExactFromToMinToAerodrome_SingleHop() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToAerodrome(path, fromAmount, minToAmount);

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

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToAerodrome(path, fromAmount, minToAmount);

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

    function _mock_SwapExactFromToMinToAerodrome(address[] memory path, uint256 fromAmount, uint256 minToAmount)
        internal
        returns (ISwapAdapter.SwapContext memory swapContext)
    {
        swapContext = ISwapAdapter.SwapContext({
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

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](path.length - 1);
        for (uint256 i = 0; i < path.length - 1; i++) {
            routes[i] = IAerodromeRouter.Route(path[i], path[i + 1], false, aerodromeFactory);
        }

        MockAerodromeRouter.MockSwap memory mockSwap = MockAerodromeRouter.MockSwap({
            fromToken: IERC20(path[0]),
            toToken: IERC20(path[path.length - 1]),
            fromAmount: fromAmount,
            toAmount: minToAmount,
            encodedRoutes: keccak256(abi.encode(routes)),
            deadline: block.timestamp,
            isExecuted: false
        });
        mockAerodromeRouter.mockNextSwap(mockSwap);

        return swapContext;
    }
}
