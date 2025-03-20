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

struct ActionData {
    /// @dev Amount of collateral added or withdrawn
    uint256 collateral;
    /// @dev Amount of debt borrowed or repaid
    uint256 debt;
    /// @dev Amount of equity added or withdrawn before fees, denominated in collateral asset
    uint256 equity;
    /// @dev Amount of shares minted or burned to user
    uint256 shares;
    /// @dev Fee charged for the action to the strategy, denominated in collateral asset
    uint256 strategyFee;
    /// @dev Fee charged for the action to the treasury, denominated in collateral asset
    uint256 treasuryFee;
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
