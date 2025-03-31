// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

interface IRebalanceAdapter is IRebalanceAdapterBase {
    /// @notice Error thrown when the caller is not the authorized creator of the rebalance adapter
    error Unauthorized();

    /// @notice Event emitted when the rebalance adapter is initialized
    event RebalanceAdapterInitialized(address indexed authorizedCreator, ILeverageManager indexed leverageManager);

    /// @notice Returns the authorized creator of the rebalance adapter
    /// @return authorizedCreator The authorized creator of the rebalance adapter
    function getAuthorizedCreator() external view returns (address authorizedCreator);

    /// @notice Returns the leverage manager of the rebalance adapter
    /// @return leverageManager The leverage manager of the rebalance adapter
    function getLeverageManager() external view returns (ILeverageManager leverageManager);
}
