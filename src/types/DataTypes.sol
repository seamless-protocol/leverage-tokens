// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
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

/// @dev Struct that contains base strategy config stored in LeverageManager
struct BaseStrategyConfig {
    /// @dev Lending adapter for strategy
    ILendingAdapter lendingAdapter;
    /// @dev Minimum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    ///      Collateral ratio is calculated as collateral value / debt value
    uint256 minCollateralRatio;
    /// @dev Maximum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    uint256 maxCollateralRatio;
    /// @dev Target collateral ratio of the strategy on 8 decimals
    uint256 targetCollateralRatio;
    /// @dev Rebalance reward distributor module for strategy
    IRebalanceRewardDistributor rebalanceRewardDistributor;
    /// @dev Whitelist module for strategy, if not set rebalance is open for everybody
    IRebalanceWhitelist rebalanceWhitelist;
}

/// @dev Struct that contains all data related to collateral ratios for a strategy
struct CollateralRatios {
    /// @dev Minimum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    ///      Collateral ratio is calculated as collateral value / debt value
    uint256 minCollateralRatio;
    /// @dev Maximum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    uint256 maxCollateralRatio;
    /// @dev Target collateral ratio of the strategy on 8 decimals
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

/// @dev Struct that contains entire strategy config
struct StrategyConfig {
    /// @dev Lending adapter for strategy
    ILendingAdapter lendingAdapter;
    /// @dev Minimum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    ///      Collateral ratio is calculated as collateral value / debt value
    uint256 minCollateralRatio;
    /// @dev Maximum collateral ratio allowed for strategy before a rebalance can occur. 8 decimals of precision
    uint256 maxCollateralRatio;
    /// @dev Target collateral ratio of the strategy on 8 decimals
    uint256 targetCollateralRatio;
    /// @dev Rebalance reward distributor module for strategy
    IRebalanceRewardDistributor rebalanceRewardDistributor;
    /// @dev Whitelist module for strategy, if not set rebalance is open for everybody
    IRebalanceWhitelist rebalanceWhitelist;
    /// @dev Strategy fee for deposit action
    uint256 strategyDepositFee;
    /// @dev Strategy fee for withdraw action
    uint256 strategyWithdrawFee;
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
