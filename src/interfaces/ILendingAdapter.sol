// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILendingAdapter {
    /// @notice Returns total collateral of the strategy
    /// @param strategy Strategy to query collateral for
    /// @return collateral Total collateral of the strategy
    function getStrategyCollateral(address strategy) external view returns (uint256 collateral);

    /// @notice Returns total collateral of the strategy denominated in debt asset of the strategy
    /// @param strategy Strategy to query collateral for
    /// @return collateral Total collateral of the strategy
    function getStrategyCollateralInDebtAsset(address strategy) external view returns (uint256 collateral);

    /// @notice Returns total debt of the strategy
    /// @param strategy Strategy to query debt for
    /// @return debt Total debt of the strategy
    function getStrategyDebt(address strategy) external view returns (uint256 debt);

    /// @notice Returns total equity of the strategy denominated in debt asset of the strategy
    /// @param strategy Strategy to query equity for
    /// @return equity Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityInDebtAsset(address strategy) external view returns (uint256 equity);

    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param strategy Address of the strategy
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(address strategy, uint256 collateral) external view returns (uint256 debt);

    /// @notice Converts amount of debt asset to collateral asset amount based on lending pool oracle
    /// @param strategy Address of the strategy
    /// @param debt Debt amount
    /// @return collateral Amount of collateral asset
    function convertDebtToCollateralAsset(address strategy, uint256 debt) external view returns (uint256 collateral);

    /// @notice Supplies assets to the lending pool
    /// @param strategy Address of the strategy
    /// @param amount Amount of assets to supply
    function addCollateral(address strategy, uint256 amount) external;

    /// @notice Withdraws assets to the lending pool
    /// @param strategy Address of the strategy
    /// @param amount Amount of assets to withdraw
    function removeCollateral(address strategy, uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param strategy Address of the strategy
    /// @param amount Amount of assets to borrow
    function borrow(address strategy, uint256 amount) external;

    /// @notice Repays debt to the lending pool
    /// @param strategy Address of the strategy
    /// @param amount Amount of assets of debt to repay
    function repay(address strategy, uint256 amount) external;
}
