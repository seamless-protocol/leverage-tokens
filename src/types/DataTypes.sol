// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

struct CollateralRatios {
    uint256 minCollateralRatio;
    uint256 maxCollateralRatio;
    uint256 targetCollateralRatio;
}

struct StrategyState {
    uint256 collateral;
    uint256 debt;
    uint256 equity;
    uint256 collateralRatio;
}
