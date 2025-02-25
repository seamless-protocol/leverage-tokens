// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapExactFromToMinToAerodromeTest} from "./SwapExactFromToMinToAerodrome.t.sol";
import {SwapExactFromToMinToAerodromeSlipstreamTest} from "./SwapExactFromToMinToAerodromeSlipstream.t.sol";
import {SwapExactFromToMinToUniV2Test} from "./SwapExactFromToMinToUniV2.t.sol";
import {SwapExactFromToMinToUniV3Test} from "./SwapExactFromToMinToUniV3.t.sol";

contract SwapExactFromToMinToTest is
    SwapExactFromToMinToAerodromeTest,
    SwapExactFromToMinToAerodromeSlipstreamTest,
    SwapExactFromToMinToUniV2Test,
    SwapExactFromToMinToUniV3Test
{
    function test_swapExactFromToMinTo_Aerodrome() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToAerodrome(path, fromAmount, minToAmount);

        deal(address(fromToken), address(this), fromAmount);
        fromToken.approve(address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.swapExactFromToMinTo(fromToken, fromAmount, minToAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_swapExactFromToMinTo_AerodromeSlipstream() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapExactFromToMinToAerodromeSlipstream(path, tickSpacing, fromAmount, minToAmount, false);

        deal(address(fromToken), address(this), fromAmount);
        fromToken.approve(address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.swapExactFromToMinTo(fromToken, fromAmount, minToAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_swapExactFromToMinTo_UniV2() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapExactFromToMinToUniV2(path, fromAmount, minToAmount);

        deal(address(fromToken), address(this), fromAmount);
        fromToken.approve(address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.swapExactFromToMinTo(fromToken, fromAmount, minToAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }

    function test_swapExactFromToMinTo_UniV3() public {
        uint256 fromAmount = 100 ether;
        uint256 minToAmount = 10 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapExactFromToMinToUniV3(path, fees, fromAmount, minToAmount, false);

        deal(address(fromToken), address(this), fromAmount);
        fromToken.approve(address(swapAdapter), fromAmount);

        uint256 toAmount = swapAdapter.swapExactFromToMinTo(fromToken, fromAmount, minToAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), minToAmount);
        assertEq(toAmount, minToAmount);
    }
}
