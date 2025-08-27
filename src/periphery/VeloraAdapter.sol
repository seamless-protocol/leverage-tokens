// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

// Dependency imports
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IVeloraAdapter} from "../interfaces/periphery/IVeloraAdapter.sol";
import {IAugustusRegistry} from "../interfaces/periphery/IAugustusRegistry.sol";
import {BytesLib} from "../libraries/BytesLib.sol";

/// @notice Adapter for trading with Velora.
/// @dev This adapter was modified from the original version implemented by Morpho
/// https://github.com/morpho-org/bundler3/blob/4887f33299ba6e60b54a51237b16e7392dceeb97/src/adapters/ParaswapAdapter.sol
contract VeloraAdapter is IVeloraAdapter {
    /* IMMUTABLES */

    /// @notice The address of the Augustus registry.
    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;

    /* CONSTRUCTOR */

    /// @param augustusRegistry The address of Velora's registry of Augustus contracts.
    constructor(address augustusRegistry) {
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
    }

    /* SWAP ACTIONS */

    /// @inheritdoc IVeloraAdapter
    function buy(
        address augustus,
        bytes memory callData,
        address inputToken,
        address outputToken,
        uint256 newOutputAmount,
        Offsets calldata offsets,
        address receiver
    ) public returns (uint256) {
        if (newOutputAmount != 0) {
            _updateExactandQuotedAmounts(callData, offsets, newOutputAmount, Math.Rounding.Floor);
        }

        // The maximum sell amount is set to the entire balance of the srcToken in the adapter
        BytesLib.set(callData, offsets.limitAmount, IERC20(inputToken).balanceOf(address(this)));

        _exactOutputSwap({
            augustus: augustus,
            callData: callData,
            inputToken: inputToken,
            outputToken: outputToken,
            minOutputAmount: BytesLib.get(callData, offsets.exactAmount),
            receiver: receiver
        });

        // Return any leftover srcToken to the sender
        uint256 excessInputAmount = IERC20(inputToken).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(inputToken), msg.sender, excessInputAmount);

        return excessInputAmount;
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Executes the swap specified by `callData` with `augustus`.
    /// @param augustus Address of the swapping contract. Must be in Velora's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @param inputToken Token to sell.
    /// @param outputToken Token to buy.
    /// @param minOutputAmount Minimum amount of `outputToken` to buy.
    /// @param receiver Address to which bought assets will be sent. Any leftover `inputToken` tokens should be skimmed
    /// separately.
    function _exactOutputSwap(
        address augustus,
        bytes memory callData,
        address inputToken,
        address outputToken,
        uint256 minOutputAmount,
        address receiver
    ) internal {
        if (!AUGUSTUS_REGISTRY.isValidAugustus(augustus)) {
            revert InvalidAugustus(augustus);
        }
        if (receiver == address(0)) {
            revert InvalidReceiver(receiver);
        }
        if (minOutputAmount == 0) {
            revert InvalidMinOutputAmount(minOutputAmount);
        }

        SafeERC20.forceApprove(IERC20(inputToken), augustus, type(uint256).max);

        // slither-disable-next-line unused-return
        Address.functionCall(augustus, callData);

        SafeERC20.forceApprove(IERC20(inputToken), augustus, 0);

        uint256 outputAmount = IERC20(outputToken).balanceOf(address(this));

        if (outputAmount < minOutputAmount) {
            revert OutputTokenSlippageTooHigh(outputAmount, minOutputAmount);
        }

        if (receiver != address(this)) {
            SafeERC20.safeTransfer(IERC20(outputToken), receiver, outputAmount);
        }
    }

    /// @notice Sets exact amount in `callData` to `exactAmount`.
    /// @notice If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.
    function _updateExactandQuotedAmounts(
        bytes memory callData,
        Offsets calldata offsets,
        uint256 exactAmount,
        Math.Rounding rounding
    ) internal pure {
        uint256 oldExactAmount = BytesLib.get(callData, offsets.exactAmount);
        BytesLib.set(callData, offsets.exactAmount, exactAmount);

        if (offsets.quotedAmount > 0) {
            uint256 quotedAmount =
                Math.mulDiv(BytesLib.get(callData, offsets.quotedAmount), exactAmount, oldExactAmount, rounding);
            BytesLib.set(callData, offsets.quotedAmount, quotedAmount);
        }
    }
}
