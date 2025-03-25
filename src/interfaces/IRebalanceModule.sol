// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";

interface IRebalanceModule {
    /// @notice Validates if strategy is eligible for rebalance
    /// @param strategy Strategy to validate
    /// @param state State of the strategy
    /// @param caller Caller of the function
    /// @return isEligible True if strategy is eligible for rebalance, false otherwise
    function isEligibleForRebalance(IStrategy strategy, StrategyState memory state, address caller)
        external
        view
        returns (bool isEligible);

    /// @notice Validates if strategy state after rebalance is valid
    /// @param strategy Strategy to validate
    /// @param stateBefore State of the strategy before rebalance
    /// @return isValid True if state after rebalance is valid, false otherwise
    function isStateAfterRebalanceValid(IStrategy strategy, StrategyState memory stateBefore)
        external
        view
        returns (bool isValid);
}
