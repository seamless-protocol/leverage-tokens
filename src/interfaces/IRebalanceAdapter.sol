// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

interface IRebalanceAdapter is IRebalanceAdapterBase {
    /// @notice Event emitted when the rebalance adapter is initialized
    event RebalanceAdapterInitialized(address authorizedCreator, ILeverageManager leverageManager);

    /// @notice Returns the authorized creator of the rebalance adapter
    /// @return authorizedCreator The authorized creator of the rebalance adapter
    function getAuthorizedCreator() external view returns (address authorizedCreator);
}
