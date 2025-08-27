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
    using Math for uint256;
    using BytesLib for bytes;

    /* IMMUTABLES */

    /// @notice The address of the Augustus registry.
    IAugustusRegistry public immutable AUGUSTUS_REGISTRY;

    /* CONSTRUCTOR */

    /// @param augustusRegistry The address of Velora's registry of Augustus contracts.
    constructor(address augustusRegistry) {
        AUGUSTUS_REGISTRY = IAugustusRegistry(augustusRegistry);
    }

    /* SWAP ACTIONS */

    /// @notice Buys an exact amount. Uses the entire balance of the srcToken in the adapter as the maximum input amount.
    /// @notice Compatibility with Augustus versions different from 6.2 is not guaranteed.
    /// @notice This function should be used immediately after sending tokens to the adapter, and any tokens remaining
    /// in the adapter after a swap should be transferred out immediately.
    /// @param augustus Address of the swapping contract. Must be in Velora's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param newDestAmount Adjusted amount to buy. Will be used to update callData before sent to Augustus contract.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @dev The quoted sell amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent. Any leftover `srcToken` should be skimmed
    /// separately.
    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        Offsets calldata offsets,
        address receiver
    ) public returns (uint256) {
        if (newDestAmount != 0) {
            updateExactandQuotedAmounts(callData, offsets, newDestAmount, Math.Rounding.Floor);
        }

        // The maximum sell amount is set to the entire balance of the srcToken in the adapter
        callData.set(offsets.limitAmount, IERC20(srcToken).balanceOf(address(this)));

        swap({
            augustus: augustus,
            callData: callData,
            srcToken: srcToken,
            destToken: destToken,
            minDestAmount: callData.get(offsets.exactAmount),
            receiver: receiver
        });

        // Return any leftover srcToken to the sender
        uint256 excessSrcAmount = IERC20(srcToken).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(srcToken), msg.sender, excessSrcAmount);

        return excessSrcAmount;
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Executes the swap specified by `callData` with `augustus`.
    /// @param augustus Address of the swapping contract. Must be in Velora's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @param srcToken Token to sell.
    /// @param destToken Token to buy.
    /// @param minDestAmount Minimum amount of `destToken` to buy.
    /// @param receiver Address to which bought assets will be sent. Any leftover `src` tokens should be skimmed
    /// separately.
    function swap(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 minDestAmount,
        address receiver
    ) internal {
        require(AUGUSTUS_REGISTRY.isValidAugustus(augustus), "INVALID_AUGUSTUS");
        require(receiver != address(0), "ZERO_ADDRESS");
        require(minDestAmount != 0, "ZERO_MIN_DEST_AMOUNT");

        uint256 destInitial = IERC20(destToken).balanceOf(address(this));

        SafeERC20.forceApprove(IERC20(srcToken), augustus, type(uint256).max);

        // slither-disable-next-line unused-return
        Address.functionCall(augustus, callData);

        SafeERC20.forceApprove(IERC20(srcToken), augustus, 0);

        uint256 destFinal = IERC20(destToken).balanceOf(address(this));

        uint256 destAmount = destFinal - destInitial;

        require(destAmount >= minDestAmount, "BUY_AMOUNT_TOO_LOW");

        if (receiver != address(this)) {
            SafeERC20.safeTransfer(IERC20(destToken), receiver, destAmount);
        }
    }

    /// @notice Sets exact amount in `callData` to `exactAmount`.
    /// @notice If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.
    function updateExactandQuotedAmounts(
        bytes memory callData,
        Offsets calldata offsets,
        uint256 exactAmount,
        Math.Rounding rounding
    ) internal pure {
        uint256 oldExactAmount = callData.get(offsets.exactAmount);
        callData.set(offsets.exactAmount, exactAmount);

        if (offsets.quotedAmount > 0) {
            uint256 quotedAmount = callData.get(offsets.quotedAmount).mulDiv(exactAmount, oldExactAmount, rounding);
            callData.set(offsets.quotedAmount, quotedAmount);
        }
    }
}
