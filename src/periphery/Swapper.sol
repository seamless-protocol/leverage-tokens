// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";

// TODO: This contract should be upgradeable, so we have the option to add support for other providers in the future
contract Swapper is ISwapper {
    /// @notice Provider used for swaps
    Provider public provider;

    /// @notice LiFi Diamond Proxy protocol contract address
    address public lifi;

    constructor(Provider _provider, address _lifi) {
        provider = _provider;
        lifi = _lifi;
    }

    function setProvider(ISwapper.Provider _provider) external {
        // TODO: Only authed role allowed to set provider
        provider = _provider;
    }

    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata providerSwapData
    ) external returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), fromAmount);

        if (provider == Provider.LiFi) {
            return _swapLiFi(fromToken, toToken, fromAmount, minToAmount, providerSwapData);
        } else {
            revert InvalidProvider();
        }
    }

    function _swapLiFi(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata providerSwapData
    ) internal returns (uint256) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), fromAmount);
        fromToken.approve(lifi, fromAmount);

        (bool success,) = lifi.call{value: msg.value}(providerSwapData);

        if (!success) {
            revert SwapFailed();
        }

        uint256 toAmount = toToken.balanceOf(address(this));
        if (toAmount < minToAmount) {
            revert SlippageTooHigh(toAmount, minToAmount);
        } else {
            return toAmount;
        }
    }
}
