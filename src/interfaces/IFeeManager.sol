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

    /// @notice Event emitted when strategy fee configuration is set
    event StrategyFeeConfigSet(address indexed strategy, Storage.StrategyFeeConfig config);

    /// @notice Event emitted when fee is charged on any action on strategy
    event FeeCharged(address indexed strategy, Action indexed action, uint256 amount, uint256 feeAmount);

    /// @notice Returns address of the treasury
    /// @return treasury Address of the treasury
    function getTreasury() external view returns (address treasury);

    /// @notice Returns entire fee configuration for strategy
    /// @param strategy Strategy to get fee config for
    /// @return config Fee configuration for strategy
    function getStrategyFeeConfig(address strategy) external view returns (Storage.StrategyFeeConfig memory config);

    /// @notice Sets address of the treasury. Treasury receives all fees from leverage manager
    /// @param treasury Address of the treasury
    /// @dev Only FEE_MANAGER role can call this function
    /// @dev Emits TreasurySet event
    function setTreasury(address treasury) external;

    /// @notice Sets fee configuration for strategy
    /// @param strategy Strategy to set fee config for
    /// @param config Entire fee configuration
    /// @dev Only FEE_MANAGER role can call this function
    /// @dev If manager tries to set some of the fees above 100% it reverts with FeeTooHigh error
    /// @dev Emits StrategyFeeConfigSet event
    function setStrategyFeeConfig(address strategy, Storage.StrategyFeeConfig memory config) external;
}
