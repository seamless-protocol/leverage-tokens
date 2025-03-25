// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";

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

/// @dev Struct that contains all data related to a leverage token action
struct ActionData {
    /// @dev Amount of collateral added or withdrawn
    uint256 collateral;
    /// @dev Amount of debt borrowed or repaid
    uint256 debt;
    /// @dev Amount of equity added or withdrawn before fees, denominated in collateral asset
    uint256 equity;
    /// @dev Amount of shares minted or burned to user
    uint256 shares;
    /// @dev Fee charged for the action to the leverage token, denominated in collateral asset
    uint256 tokenFee;
    /// @dev Fee charged for the action to the treasury, denominated in collateral asset
    uint256 treasuryFee;
}

/// @dev Struct that contains base leverage token config stored in LeverageManager
struct BaseLeverageTokenConfig {
    /// @dev Lending adapter for leverage token
    ILendingAdapter lendingAdapter;
    /// @dev Rebalance module for leverage token
    IRebalanceModule rebalanceModule;
    /// @dev Target collateral ratio of the leverage token on 8 decimals
    uint256 targetCollateralRatio;
}

/// @dev Struct that contains all data related to a rebalance action
struct RebalanceAction {
    /// @dev Leverage token to perform the action on
    ILeverageToken leverageToken;
    /// @dev Type of action to perform
    ActionType actionType;
    /// @dev Amount to perform the action with
    uint256 amount;
}

/// @dev Struct that contains entire leverage token config
struct LeverageTokenConfig {
    /// @dev Lending adapter for leverage token
    ILendingAdapter lendingAdapter;
    /// @dev Rebalance module for leverage token
    IRebalanceModule rebalanceModule;
    /// @dev Target collateral ratio of the leverage token on 8 decimals
    uint256 targetCollateralRatio;
    /// @dev Fee for deposit action
    uint256 depositTokenFee;
    /// @dev Fee for withdraw action
    uint256 withdrawTokenFee;
}

/// @dev Struct that contains all data describing the state of a leverage token
struct LeverageTokenState {
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

/// @dev Struct containing auction parameters
struct Auction {
    /// @dev Whether the leverage token is over-collateralized
    bool isOverCollateralized;
    /// @dev Initial price multiplier for the auction
    uint256 initialPriceMultiplier;
    /// @dev Minimum price multiplier for the auction
    uint256 minPriceMultiplier;
    /// @dev Timestamp when auction started
    uint256 startTimestamp;
    /// @dev Timestamp when auction ends/ended
    uint256 endTimestamp;
}
