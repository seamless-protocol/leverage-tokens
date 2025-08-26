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

    function buy(
        address augustus,
        bytes memory callData,
        address srcToken,
        address destToken,
        uint256 newDestAmount,
        Offsets calldata offsets,
        address receiver
    ) external;

    function erc20Transfer(address token, address receiver, uint256 amount) external;
}
