// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/ISwapAdapter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";

contract SwapAdapterHarness is SwapAdapter {
    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }

    function exposed_swapExactFromToMinToAerodrome(
        uint256 fromAmount,
        uint256 minToAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 toAmount) {
        return _swapExactFromToMinToAerodrome(fromAmount, minToAmount, swapContext);
    }

    function exposed_swapExactFromToMinToAerodromeSlipstream(
        uint256 fromAmount,
        uint256 minToAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 toAmount) {
        return _swapExactFromToMinToAerodromeSlipstream(fromAmount, minToAmount, swapContext);
    }

    function exposed_swapExactFromToMinToUniV2(
        uint256 fromAmount,
        uint256 minToAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 toAmount) {
        return _swapExactFromToMinToUniV2(fromAmount, minToAmount, swapContext);
    }

    function exposed_swapExactFromToMinToUniV3(
        uint256 fromAmount,
        uint256 minToAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 toAmount) {
        return _swapExactFromToMinToUniV3(fromAmount, minToAmount, swapContext);
    }

    function exposed_swapMaxFromToExactToAerodrome(
        uint256 toAmount,
        uint256 maxFromAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 fromAmount) {
        return _swapMaxFromToExactToAerodrome(toAmount, maxFromAmount, swapContext);
    }

    function exposed_swapMaxFromToExactToAerodromeSlipstream(
        uint256 toAmount,
        uint256 maxFromAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 fromAmount) {
        return _swapMaxFromToExactToAerodromeSlipstream(toAmount, maxFromAmount, swapContext);
    }

    function exposed_swapMaxFromToExactToUniV2(
        uint256 toAmount,
        uint256 maxFromAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 fromAmount) {
        return _swapMaxFromToExactToUniV2(toAmount, maxFromAmount, swapContext);
    }

    function exposed_swapMaxFromToExactToUniV3(
        uint256 toAmount,
        uint256 maxFromAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 fromAmount) {
        return _swapMaxFromToExactToUniV3(toAmount, maxFromAmount, swapContext);
    }
}
