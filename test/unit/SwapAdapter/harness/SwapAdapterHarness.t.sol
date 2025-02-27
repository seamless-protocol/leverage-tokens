// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";

contract SwapAdapterHarness is SwapAdapter {
    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }

    function exposed_swapExactInputAerodrome(
        uint256 inputAmount,
        uint256 minOutputAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 outputAmount) {
        return _swapExactInputAerodrome(inputAmount, minOutputAmount, swapContext);
    }

    function exposed_swapExactInputAerodromeSlipstream(
        uint256 inputAmount,
        uint256 minOutputAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 outputAmount) {
        return _swapExactInputAerodromeSlipstream(inputAmount, minOutputAmount, swapContext);
    }

    function exposed_swapExactInputUniV2(
        uint256 inputAmount,
        uint256 minOutputAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 outputAmount) {
        return _swapExactInputUniV2(inputAmount, minOutputAmount, swapContext);
    }

    function exposed_swapExactInputUniV3(
        uint256 inputAmount,
        uint256 minOutputAmount,
        ISwapAdapter.SwapContext memory swapContext
    ) external returns (uint256 outputAmount) {
        return _swapExactInputUniV3(inputAmount, minOutputAmount, swapContext);
    }
}
