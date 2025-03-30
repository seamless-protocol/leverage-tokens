// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

interface IPreLiquidationRebalanceAdapter {
    /// @notice Returns the leverage manager contract
    /// @return leverageManager The leverage manager contract
    function getLeverageManager() external view returns (ILeverageManager leverageManager);

    /// @notice Returns the health factor threshold for rebalancing
    /// @return healthFactorThreshold The health factor threshold for rebalancing
    /// @dev When leverage token health factor is below this threshold, the leverage token will be rebalanced
    function getHealthFactorThreshold() external view returns (uint256 healthFactorThreshold);

    /// @notice Returns the rebalance reward percentage
    /// @return rebalanceRewardPercentage The rebalance reward percentage
    /// @dev The rebalance reward represents the percentage of liquidation cost that will be rewarded to the caller of the
    ///      rebalance function. 10000 means 100%
    function getRebalanceReward() external view returns (uint256 rebalanceRewardPercentage);

    /// @notice Returns true if the state after rebalance is valid
    /// @param token The leverage token
    /// @param stateBefore The state before rebalance
    /// @return isValid True if the state after rebalance is valid
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        external
        view
        returns (bool isValid);

    /// @notice Returns true if the leverage token is eligible for rebalance
    /// @param token The leverage token
    /// @param stateBefore The state before rebalance
    /// @param caller The caller of the rebalance function
    /// @return isEligible True if the leverage token is eligible for rebalance
    /// @dev Token is eligible for rebalance if health factor is below the threshold
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory stateBefore, address caller)
        external
        view
        returns (bool isEligible);
}
