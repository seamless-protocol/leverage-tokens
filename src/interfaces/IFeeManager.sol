// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IStrategy} from "./IStrategy.sol";
import {ExternalAction} from "src/types/DataTypes.sol";

interface IFeeManager {
    /// @notice Error emitted when fee manager tries to set fee higher than MAX_FEE
    error FeeTooHigh(uint256 fee, uint256 maxFee);

    /// @notice Error emitted when trying to set treasury fee when treasury address is not set
    error TreasuryNotSet();

    /// @notice Emitted when fee is set for strategy for specific action
    event StrategyActionFeeSet(IStrategy strategy, ExternalAction action, uint256 fee);

    /// @notice Emitted when treasury fee is set for specific action
    event TreasuryActionFeeSet(ExternalAction indexed action, uint256 fee);

    /// @notice Emitted when treasury is set
    event TreasurySet(address treasury);

    /// @notice Returns fee for specific action on strategy
    /// @param strategy Strategy to get fee for
    /// @param action Action to get fee for
    /// @return fee Fee for action on strategy, 100_00 is 100%
    function getStrategyActionFee(IStrategy strategy, ExternalAction action) external view returns (uint256 fee);

    /// @notice Returns address of the treasury
    /// @return treasury Address of the treasury
    function getTreasury() external view returns (address treasury);

    /// @notice Returns treasury fee for specific action
    /// @param action Action to get fee for
    /// @return fee Fee for action, 100_00 is 100%
    function getTreasuryActionFee(ExternalAction action) external view returns (uint256 fee);

    /// @notice Sets fee for specific action on strategy
    /// @param strategy Strategy to set fee for
    /// @param action Action to set fee for
    /// @param fee Fee for action on strategy, 100_00 is 100%
    /// @dev Only FEE_MANAGER role can call this function.
    ///      If manager tries to set fee above 100% it reverts with FeeTooHigh error
    function setStrategyActionFee(IStrategy strategy, ExternalAction action, uint256 fee) external;

    /// @notice Sets address of the treasury. Treasury receives all fees from LeverageManager. If the treasury is set to
    ///         the zero address, the treasury fees are reset to 0 as well
    /// @param treasury Address of the treasury
    /// @dev Only FEE_MANAGER role can call this function
    /// @dev Emits TreasurySet event
    function setTreasury(address treasury) external;

    /// @notice Sets fee for specific action
    /// @param action Action to set fee for
    /// @param fee Fee for action, 100_00 is 100%
    /// @dev Only FEE_MANAGER role can call this function.
    ///      If manager tries to set fee above 100% it reverts with FeeTooHigh error
    function setTreasuryActionFee(ExternalAction action, uint256 fee) external;
}
