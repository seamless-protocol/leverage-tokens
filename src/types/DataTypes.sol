// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IStrategy} from "src/interfaces/IStrategy.sol";

/// @dev Enum defining the type of external action user can perform
enum ExternalAction {
    Deposit,
    Withdraw
}

/// @dev Enum defining the type of internal action the lending adapter manager can perform on lending pool
enum ActionType {
    AddCollateral,
    RemoveCollateral,
    Borrow,
    Repay
}

/// @dev Struct that contains all data related to collateral ratios for a strategy
struct CollateralRatios {
    /// @dev Minimum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
    ///      Collateral ratio is calculated as collateral value / debt value
    uint256 minCollateralRatio;
    /// @dev Maximum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
    uint256 maxCollateralRatio;
    /// @dev Target collateral ratio allowed for strategy before triggering rebalance on 8 decimals
    uint256 targetCollateralRatio;
}

/// @dev Struct that contains all data related to a rebalance action
struct RebalanceAction {
    /// @dev Strategy to perform the action on
    IStrategy strategy;
    /// @dev Type of action to perform
    ActionType actionType;
    /// @dev Amount to perform the action with
    uint256 amount;
}

/// @dev Struct that contains all data describing the state of a strategy
struct StrategyState {
    /// @dev Collateral denominated in debt asset
    uint256 collateralInDebtAsset;
    /// @dev Debt
    uint256 debt;
    /// @dev Equity denominated in debt asset
    uint256 equity;
    /// @dev Collateral ratio on 8 decimals
    uint256 collateralRatio;
}

/// @dev Struct that contains all data related to a token transfer
struct TokenTransfer {
    /// @dev Token to transfer
    address token;
    /// @dev Amount to transfer
    uint256 amount;
}
