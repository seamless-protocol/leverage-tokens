// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILendingAdapter {
    /// @notice Returns total collateral of the strategy
    /// @param strategyId Strategy to query collateral for
    /// @return collateral Total collateral of the strategy
    function getStrategyCollateral(uint256 strategyId) external view returns (uint256 collateral);

    /// @notice Returns total equity of the strategy denominated in debt asset of the strategy
    /// @param strategyId Strategy to query equity for
    /// @return equity Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityInDebtAsset(uint256 strategyId) external view returns (uint256 equity);

    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param strategyId Address of the strategy
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(uint256 strategyId, uint256 collateral)
        external
        view
        returns (uint256 debt);

    /// @notice Supplies assets to the lending pool
    /// @param strategyId Strategy
    /// @param amount Amount of assets to supply
    function addCollateral(uint256 strategyId, uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param strategyId Strategy
    /// @param amount Amount of assets to borrow
    function borrow(uint256 strategyId, uint256 amount) external;
}
