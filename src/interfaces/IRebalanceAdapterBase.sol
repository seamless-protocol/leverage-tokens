// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

/// @title IRebalanceAdapterBase
/// @notice Interface for the base rebalance adapter
/// @dev This is minimal interface required for the rebalance adapter to be used by the LeverageManager
interface IRebalanceAdapterBase {
    /// @notice Returns the initial collateral ratio for the leverage token
    /// @param token Leverage token to get initial collateral ratio for
    /// @return initialCollateralRatio Initial collateral ratio for the leverage token
    /// @dev Initial collateral ratio is followed in deposits on leverage manager when leverage token is empty
    function getInitialCollateralRatio(ILeverageToken token) external view returns (uint256 initialCollateralRatio);

    /// @notice Validates if leverage token is eligible for rebalance
    /// @param token Leverage token to validate
    /// @param state State of the leverage token
    /// @param caller Caller of the function
    /// @return isEligible True if leverage token is eligible for rebalance, false otherwise
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address caller)
        external
        view
        returns (bool isEligible);

    /// @notice Validates if leverage token state after rebalance is valid
    /// @param token Leverage token to validate
    /// @param stateBefore State of the leverage token before rebalance
    /// @return isValid True if state after rebalance is valid, false otherwise
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        external
        view
        returns (bool isValid);

    /// @notice Post-LeverageToken creation hook. Used for any validation logic or initialization after a LeverageToken
    /// is created using this adapter
    /// @param creator The address of the creator of the LeverageToken
    /// @param leverageToken The address of the LeverageToken that was created
    /// @dev This function is called in `LeverageManager.createNewLeverageToken` after the new LeverageToken is created
    function postLeverageTokenCreation(address creator, address leverageToken) external;
}
