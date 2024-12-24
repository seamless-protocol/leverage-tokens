// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILendingContract {
    /// @notice Returns total collateral of the strategy denominated in debt asset of the strategy
    /// @param strategyId Strategy to query collateral for
    /// @return collateral Total collateral of the strategy
    function getStrategyCollateralInDebtAsset(uint256 strategyId) external pure returns (uint256 collateral);

    /// @notice Returns total strategy debt denominated in debt asset of the strategy
    /// @param strategyId Strategy to query debt for
    /// @return debt Total debt of the strategy
    function getStrategyDebt(uint256 strategyId) external pure returns (uint256 debt);

    /// @notice Returns total equity of the strategy denominated in debt asset of the strategy
    /// @param strategyId Strategy to query equity for
    /// @return equity Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityInDebtAsset(uint256 strategyId) external pure returns (uint256 equity);

    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param strategyId Address of the strategy
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(uint256 strategyId, uint256 collateral)
        external
        pure
        returns (uint256 debt);

    /// @notice Returns collateral value denominated in base asset, base asset can be USD or any other asset
    /// @param strategyId Address of the strategy
    /// @param collateral Collateral amount
    /// @return collateralUSD USD value of collateral
    function convertCollateralToBaseAsset(uint256 strategyId, uint256 collateral)
        external
        pure
        returns (uint256 collateralUSD);

    /// @notice Converts amount of base asset to debt asset amount based on lending pool oracle
    /// @param strategyId Address of the strategy
    /// @param base Base asset amount
    /// @return debt Amount of debt asset
    function convertBaseToDebtAsset(uint256 strategyId, uint256 base) external pure returns (uint256 debt);

    /// @notice Converts amount of base asset to collateral asset amount based on lending pool oracle
    /// @param strategyId Address of the strategy
    /// @param base Base asset amount
    /// @return collateral Amount of collateral asset
    function convertBaseToCollateralAsset(uint256 strategyId, uint256 base) external returns (uint256 collateral);

    /// @notice Supplies assets to the lending pool
    /// @param strategyId Address of the strategy
    /// @param amount Amount of assets to supply
    function supply(uint256 strategyId, uint256 amount) external;

    /// @notice Withdraws collateral asset from lending pool
    /// @param strategyId Address of the strategy
    /// @param amount Amount of collateral to withdraw
    function withdraw(uint256 strategyId, uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param strategyId Address of the strategy
    /// @param amount Amount of assets to borrow
    function borrow(uint256 strategyId, uint256 amount) external;

    /// @notice Repays the debt on the lending pool
    /// @param strategyId Address of the strategy
    /// @param amount Debt to cover
    function repay(uint256 strategyId, uint256 amount) external;
}
