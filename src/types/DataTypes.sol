// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IStrategy} from "src/interfaces/IStrategy.sol";

enum ActionType {
    AddCollateral,
    RemoveCollateral,
    Borrow,
    Repay
}

struct CollateralRatios {
    uint256 minCollateralRatio;
    uint256 maxCollateralRatio;
    uint256 targetCollateralRatio;
}

struct RebalanceAction {
    IStrategy strategy;
    ActionType actionType;
    uint256 amount;
}

struct StrategyState {
    uint256 collateralInDebtAsset;
    uint256 debt;
    uint256 equity;
    uint256 collateralRatio;
}

struct TokenTransfer {
    address token;
    uint256 amount;
}
