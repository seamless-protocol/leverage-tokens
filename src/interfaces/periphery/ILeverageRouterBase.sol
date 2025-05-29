// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";

interface ILeverageRouterBase {
    /// @notice Error thrown when the cost of a swap exceeds the maximum allowed cost
    /// @param actualCost The actual cost of the swap
    /// @param maxCost The maximum allowed cost of the swap
    error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);

    /// @notice Error thrown when the caller is not authorized to execute a function
    error Unauthorized();

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);
}
