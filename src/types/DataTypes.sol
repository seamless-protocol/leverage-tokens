// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

struct CollateralRatios {
    uint256 minCollateralRatio;
    uint256 maxCollateralRatio;
    uint256 targetCollateralRatio;
}

struct DepositParams {
    IStrategy strategy;
    IERC20 collateralAsset;
    IERC20 debtAsset;
    uint256 collateralFromSender;
    uint256 equityInCollateralAsset;
    uint256 requiredCollateral;
    uint256 requiredDebt;
    uint256 minShares;
    address receiver;
    bytes providerSwapData;
}

struct MorphoCallbackData {
    IFeeManager.Action action;
    bytes actionData;
}
