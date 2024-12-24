// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FeeManagerStorage as Storage} from "../storage/FeeManagerStorage.sol";

interface IFeeManager {
    /// @notice Enum representing all action types on which fee can be charged
    enum Action {
        Deposit,
        Withdraw,
        Compound
    }

    /// @notice Error emitted when fee manager tries to set fee higher than MAX_FEE
    error FeeTooHigh();

    /// @notice Emitted when treasury address is set
    event TreasurySet(address treasury);

    /// @notice Emitted when fee is set for strategy for specific action
    event StrategyActionFeeSet(uint256 strategyId, IFeeManager.Action action, uint256 fee);

    /// @notice Event emitted when fee is charged on any action on strategy
    event FeeCharged(uint256 indexed strategy, Action indexed action, uint256 amount, uint256 feeAmount);

    /// @notice Returns address of the treasury
    /// @return treasury Address of the treasury
    function getTreasury() external view returns (address treasury);

    /// @notice Returns fee for specific action on strategy
    /// @param strategyId Strategy to get fee for
    /// @param action Action to get fee for
    /// @return fee Fee for action on strategy, 100_00 is 100%
    function getStrategyActionFee(uint256 strategyId, Action action) external view returns (uint256 fee);

    /// @notice Sets address of the treasury. Treasury receives all fees from leverage manager
    /// @param treasury Address of the treasury
    /// @dev Only FEE_MANAGER role can call this function
    /// @dev Emits TreasurySet event
    function setTreasury(address treasury) external;

    /// @notice Sets fee for specific action on strategy
    /// @param strategyId Strategy to set fee for
    /// @param action Action to set fee for
    /// @param fee Fee for action on strategy, 100_00 is 100%
    /// @dev Only FEE_MANAGER role can call this function.
    ///      If manager tries to set fee above 100% it reverts with FeeTooHigh error
    function setStrategyActionFee(uint256 strategyId, Action action, uint256 fee) external;
}
