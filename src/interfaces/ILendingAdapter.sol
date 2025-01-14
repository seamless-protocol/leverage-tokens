// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

interface ILendingAdapter {
    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(uint256 collateral) external view returns (uint256 debt);

    /// @notice Returns total collateral of the position held by the lending adapter
    /// @return collateral Total collateral of the position held by the lending adapter
    function getCollateral() external view returns (uint256 collateral);

    /// @notice Returns total equity of the position held by the lending adapter denominated in debt asset
    /// @return equity Equity of the position held by the lending adapter
    /// @dev Equity is calculated as collateral - debt
    function getEquityInDebtAsset() external view returns (uint256 equity);

    /// @notice Supplies assets to the lending pool
    /// @param amount Amount of assets to supply
    function addCollateral(uint256 amount) external;

    /// @notice Withdraws assets to the lending pool
    /// @param amount Amount of assets to withdraw
    function removeCollateral(uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param amount Amount of assets to borrow
    function borrow(uint256 amount) external;

    /// @notice Repays debt to the lending pool
    /// @param amount Amount of assets of debt to repay
    function repay(uint256 amount) external;
}
