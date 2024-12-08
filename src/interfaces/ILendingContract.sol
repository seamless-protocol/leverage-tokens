// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILendingContract {
    /// @notice Returns total collateral of the strategy denominated in base asset of the strategy
    /// @param strategy Strategy to query collateral for
    /// @return collateral Total collateral of the strategy
    function getStrategyCollateralInBaseAsset(address strategy) external pure returns (uint256 collateral);

    /// @notice Returns total strategy debt denominated in base asset of the strategy
    /// @param strategy Strategy to query debt for
    /// @return debt Total debt of the strategy
    function getStrategyDebtInBaseAsset(address strategy) external pure returns (uint256 debt);

    /// @notice Returns total equity of the strategy denominated in base asset of the strategy
    /// @param strategy Strategy to query equity for
    /// @return equity Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityInBaseAsset(address strategy) external pure returns (uint256 equity);

    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param strategyConfig Strategy configuration
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(Storage.StrategyConfig memory strategyConfig, uint256 collateral)
        external
        pure
        returns (uint256 debt);

    /// @notice Returns collateral value denominated in base asset, base asset can be USD or any other asset
    /// @param strategyConfig Strategy configuration
    /// @param collateral Collateral amount
    /// @return collateralUSD USD value of collateral
    function convertCollateralToBaseAsset(Storage.StrategyConfig memory strategyConfig, uint256 collateral)
        external
        pure
        returns (uint256 collateralUSD);

    /// @notice Converts amount of base asset to debt asset amount based on lending pool oracle
    /// @param strategyConfig Strategy configuration
    /// @param base Base asset amount
    /// @return debt Amount of debt asset
    function convertBaseToDebtAsset(Storage.StrategyConfig memory strategyConfig, uint256 base)
        external
        pure
        returns (uint256 debt);

    /// @notice Converts amount of base asset to collateral asset amount based on lending pool oracle
    /// @param strategyConfig Strategy configuration
    /// @param base Base asset amount
    /// @return collateral Amount of collateral asset
    function convertBaseToCollateralAsset(Storage.StrategyConfig memory strategyConfig, uint256 base)
        external
        returns (uint256 collateral);

    /// @notice Supplies assets to the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of assets to supply
    function supply(Storage.StrategyConfig memory strategyConfig, uint256 amount) external;

    /// @notice Withdraws collateral asset from lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of collateral to withdraw
    function withdraw(Storage.StrategyConfig memory strategyConfig, uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of assets to borrow
    function borrow(Storage.StrategyConfig memory strategyConfig, uint256 amount) external;

    /// @notice Repays the debt on the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Debt to cover
    function repay(Storage.StrategyConfig memory strategyConfig, uint256 amount) external;
}
