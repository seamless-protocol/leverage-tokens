// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LeverageManagerStorage as Storage} from "../storage/LeverageManagerStorage.sol";

library LendingLib {
    /// @notice Returns the total collateral of strategy denominated in collateral asset
    /// @param strategy The strategy to query collateral for
    /// @return collateral The total collateral of the strategy
    function getStrategyCollateral(address strategy) internal pure returns (uint256 collateral) {
        return 0;
    }

    /// @notice Returns total debt of the strategy denominated in debt asset
    /// @param strategy Strategy to get debt for
    /// @return debt Total debt of the strategy
    function getStrategyDebt(address strategy) internal pure returns (uint256 debt) {
        return 0;
    }

    /// @notice Returns the total collateral of the strategy denominated in USD
    /// @param strategy The strategy to query collateral for
    /// @return collateralUSD The total collateral of the strategy
    function getStrategyCollateralUSD(address strategy) internal pure returns (uint256 collateralUSD) {
        return 0;
    }

    /// @notice Returns total strategy debt denominated in USD
    /// @param strategy The strategy to query debt for
    /// @return debtUSD The total debt of the strategy
    function getStrategyDebtUSD(address strategy) internal pure returns (uint256 debtUSD) {
        return 0;
    }

    /// @notice Returns total equity of the strategy denominated in USD
    /// @param strategy Strategy to query equity for
    /// @return equityUSD Equity of the strategy
    /// @dev Equity is calculated as collateral - debt
    function getStrategyEquityUSD(address strategy) internal pure returns (uint256 equityUSD) {
        return getStrategyCollateralUSD(strategy) - getStrategyDebtUSD(strategy);
    }

    /// @notice Returns USD value of collateral assets
    /// @param strategyConfig Strategy configuration
    /// @param collateral Collateral amount
    /// @return collateralUSD USD value of collateral
    function convertCollateralToUSD(Storage.StrategyConfig storage strategyConfig, uint256 collateral)
        internal
        pure
        returns (uint256 collateralUSD)
    {
        // Fetches oracle and price of collateral asset from underlying lending pool
        // TODO: Figure out maybe StrategyConfig is not the right parameter, maybe only lending pool is enough
        return 0;
    }

    /// @notice Converts USD amount to debt tokens
    /// @param strategyConfig Strategy configuration
    /// @param debtUSD USD value to convert to debt tokens
    /// @return debt Amount of debt tokens
    function convertUSDToDebt(Storage.StrategyConfig storage strategyConfig, uint256 debtUSD)
        internal
        pure
        returns (uint256 debt)
    {
        return 0;
    }

    /// @notice Converts USD amount to collateral tokens
    /// @param strategyConfig Strategy configuration
    /// @param collateralUSD USD value to convert to collateral tokens
    /// @return collateral Amount of collateral tokens
    function convertUSDToCollateral(Storage.StrategyConfig storage strategyConfig, uint256 collateralUSD)
        internal
        pure
        returns (uint256 collateral)
    {
        return 0;
    }

    /// @notice Supplies assets to the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of assets to supply
    function supply(Storage.StrategyConfig storage strategyConfig, uint256 amount) internal {}

    /// @notice Withdraws collateral asset from lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of collateral to withdraw
    function withdraw(Storage.StrategyConfig storage strategyConfig, uint256 amount) internal {}

    /// @notice Borrows assets from the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Amount of assets to borrow
    function borrow(Storage.StrategyConfig storage strategyConfig, uint256 amount) internal {}

    /// @notice Repays the debt on the lending pool
    /// @param strategyConfig Strategy configuration
    /// @param amount Debt to cover
    function repay(Storage.StrategyConfig storage strategyConfig, uint256 amount) internal {}
}
