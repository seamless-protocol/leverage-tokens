// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

interface IRebalanceModule {
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
}
