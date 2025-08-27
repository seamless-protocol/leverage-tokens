// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

/// @notice Interface of Velora Adapter.
/// @dev This adapter was copied from the original version implemented by Morpho
/// https://github.com/morpho-org/bundler3/blob/4887f33299ba6e60b54a51237b16e7392dceeb97/src/interfaces/IParaswapAdapter.sol
interface IVeloraAdapter {
    /// @notice The offsets are:
    ///  - exactAmount, the offset in augustus calldata of the exact amount to sell / buy.
    ///  - limitAmount, the offset in augustus calldata of the minimum amount to buy / maximum amount to sell
    ///  - quotedAmount, the offset in augustus calldata of the initially quoted buy amount / initially quoted sell amount.
    /// Set to 0 if the quoted amount is not present in augustus calldata so that it is not used.
    struct Offsets {
        uint256 exactAmount;
        uint256 limitAmount;
        uint256 quotedAmount;
    }

    /// @notice Thrown when the amount of `outputToken` received is less than the minimum amount expected
    error OutputTokenSlippageTooHigh(uint256 outputAmount, uint256 minOutputAmount);

    /// @notice Thrown when the Augustus address is not in the Augustus registry
    error InvalidAugustus(address augustus);

    /// @notice Thrown when the minimum amount to buy is zero
    error InvalidMinOutputAmount(uint256 minOutputAmount);

    /// @notice Thrown when the receiver is the zero address
    error InvalidReceiver(address receiver);

    /// @notice Buys an exact amount. Uses the entire balance of the inputToken in the adapter as the maximum input amount.
    /// @notice Compatibility with Augustus versions different from 6.2 is not guaranteed.
    /// @notice This function should be used immediately after sending tokens to the adapter
    /// @notice Any tokens remaining in the adapter after a swap are transferred back to the sender
    /// @param augustus Address of the swapping contract. Must be in Velora's Augustus registry.
    /// @param callData Swap data to call `augustus`. Contains routing information.
    /// @param inputToken Token to sell.
    /// @param outputToken Token to buy.
    /// @param newOutputAmount Adjusted amount to buy. Will be used to update callData before sent to Augustus contract.
    /// @param offsets Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`)
    /// and quoted sell amount (`quotedAmount`).
    /// @dev The quoted sell amount will change only if its offset is not zero.
    /// @param receiver Address to which bought assets will be sent. Any leftover `inputToken` should be skimmed
    /// separately.
    /// @return excessInputAmount The amount of `inputToken` that was not used in the swap.
    function buy(
        address augustus,
        bytes memory callData,
        address inputToken,
        address outputToken,
        uint256 newOutputAmount,
        Offsets calldata offsets,
        address receiver
    ) external returns (uint256 excessInputAmount);
}
