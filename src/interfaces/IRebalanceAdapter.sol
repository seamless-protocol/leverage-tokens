// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

interface IRebalanceAdapter is IRebalanceAdapterBase {
    /// @notice Error thrown when the caller is not the authorized creator of the RebalanceAdapter
    error Unauthorized();

    /// @notice Event emitted when the rebalance adapter is initialized
    event RebalanceAdapterInitialized(address authorizedCreator, ILeverageManager leverageManager);

    /// @notice Returns the authorized creator of the RebalanceAdapter
    /// @return authorizedCreator The authorized creator of the RebalanceAdapter
    function getAuthorizedCreator() external view returns (address authorizedCreator);

    /// @notice Returns the LeverageManager of the RebalanceAdapter
    /// @return leverageManager The LeverageManager of the RebalanceAdapter
    function getLeverageManager() external view returns (ILeverageManager leverageManager);
}
