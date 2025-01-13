// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "./ILendingAdapter.sol";
import {Id, IMorpho} from "../vendor/morpho/IMorpho.sol";

interface IMorphoLendingAdapter is ILendingAdapter {
    /// @notice Emitted when the Morpho lending adapter is initialized
    event Initialized(IMorpho morpho, Id marketId);

    /// @notice Initializes the Morpho lending adapter
    /// @param morpho Morpho core protocol contract
    /// @param marketId Market ID of the Morpho lending pool
    function initialize(IMorpho morpho, Id marketId) external;

    /// @notice The Morpho core protocol contract
    function morpho() external view returns (IMorpho);

    /// @notice The market ID of the Morpho lending pool
    function marketId() external view returns (Id);
}
