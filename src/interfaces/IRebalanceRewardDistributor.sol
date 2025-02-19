// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {StrategyState} from "src/types/DataTypes.sol";

interface IRebalanceRewardDistributor {
    /// @notice Calculate reward for rebalance caller
    /// @param strategy Strategy address
    /// @param stateBefore State of the strategy before rebalance
    /// @param stateAfter State of the strategy after rebalance
    /// @return reward Reward for rebalance caller
    /// @dev This function is called by the LeverageManager contract to calculate reward for rebalance caller
    function computeRebalanceReward(address strategy, StrategyState memory stateBefore, StrategyState memory stateAfter)
        external
        view
        returns (uint256 reward);
}
