// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapMaxFromToExactToAerodromeTest} from "./SwapMaxFromToExactToAerodrome.t.sol";
import {SwapMaxFromToExactToAerodromeSlipstreamTest} from "./SwapMaxFromToExactToAerodromeSlipstream.t.sol";
import {SwapMaxFromToExactToUniV2Test} from "./SwapMaxFromToExactToUniV2.t.sol";
import {SwapMaxFromToExactToUniV3Test} from "./SwapMaxFromToExactToUniV3.t.sol";

contract SwapMaxFromToExactToTest is
    SwapMaxFromToExactToAerodromeTest,
    SwapMaxFromToExactToAerodromeSlipstreamTest,
    SwapMaxFromToExactToUniV2Test,
    SwapMaxFromToExactToUniV3Test
{
    function test_swapMaxFromToExactTo_Aerodrome() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToAerodrome(path, toAmount, maxFromAmount);

        deal(address(fromToken), address(this), maxFromAmount);
        fromToken.approve(address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.swapMaxFromToExactTo(fromToken, toAmount, maxFromAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_swapMaxFromToExactTo_AerodromeSlipstream() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        int24[] memory tickSpacing = new int24[](1);
        tickSpacing[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToAerodromeSlipstream(path, tickSpacing, toAmount, maxFromAmount, false);

        deal(address(fromToken), address(this), maxFromAmount);
        fromToken.approve(address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.swapMaxFromToExactTo(fromToken, toAmount, maxFromAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_swapMaxFromToExactTo_UniV2() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        ISwapAdapter.SwapContext memory swapContext = _mock_SwapMaxFromToExactToUniV2(path, toAmount, maxFromAmount);

        deal(address(fromToken), address(this), maxFromAmount);
        fromToken.approve(address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.swapMaxFromToExactTo(fromToken, toAmount, maxFromAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }

    function test_swapMaxFromToExactTo_UniV3() public {
        uint256 toAmount = 10 ether;
        uint256 maxFromAmount = 100 ether;

        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        ISwapAdapter.SwapContext memory swapContext =
            _mock_SwapMaxFromToExactToUniV3(path, fees, toAmount, maxFromAmount, false);

        deal(address(fromToken), address(this), maxFromAmount);
        fromToken.approve(address(swapAdapter), maxFromAmount);

        uint256 fromAmount = swapAdapter.swapMaxFromToExactTo(fromToken, toAmount, maxFromAmount, swapContext);

        assertEq(fromToken.balanceOf(address(this)), 0);
        assertEq(toToken.balanceOf(address(this)), toAmount);
        assertEq(fromAmount, maxFromAmount);
    }
}
