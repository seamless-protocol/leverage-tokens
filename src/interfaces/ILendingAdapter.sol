// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingAdapter {
    /// @notice Error thrown when the caller is unauthorized to call a function
    error Unauthorized();

    /// @notice Returns the address of the collateral asset
    /// @return collateralAsset Address of the collateral asset
    function getCollateralAsset() external view returns (IERC20 collateralAsset);

    /// @notice Returns the address of the debt asset
    /// @return debtAsset Address of the debt asset
    function getDebtAsset() external view returns (IERC20 debtAsset);

    /// @notice Converts amount of collateral asset to debt asset amount based on lending pool oracle
    /// @param collateral Collateral amount
    /// @return debt Amount of debt asset
    function convertCollateralToDebtAsset(uint256 collateral) external view returns (uint256 debt);

    /// @notice Converts amount of debt asset to collateral asset amount based on lending pool oracle
    /// @param debt Debt amount
    /// @return collateral Amount of collateral asset
    function convertDebtToCollateralAsset(uint256 debt) external view returns (uint256 collateral);

    /// @notice Returns total collateral of the position held by the lending adapter
    /// @return collateral Total collateral of the position held by the lending adapter
    function getCollateral() external view returns (uint256 collateral);

    /// @notice Returns total collateral of the position held by the lending adapter denominated in debt asset
    /// @return collateral Total collateral of the position held by the lending adapter denominated in debt asset
    function getCollateralInDebtAsset() external view returns (uint256 collateral);

    /// @notice Returns total debt of the position held by the lending adapter
    /// @return debt Total debt of the position held by the lending adapter
    function getDebt() external view returns (uint256 debt);

    /// @notice Returns total equity of the position held by the lending adapter denominated in collateral asset
    /// @return equity Equity of the position held by the lending adapter
    function getEquityInCollateralAsset() external view returns (uint256 equity);

    /// @notice Returns total equity of the position held by the lending adapter denominated in debt asset
    /// @return equity Equity of the position held by the lending adapter
    /// @dev Equity is calculated as collateral - debt
    function getEquityInDebtAsset() external view returns (uint256 equity);

    /// @notice Returns the health factor of the position held by the lending adapter
    /// @return healthFactor Health factor of the position held by the lending adapter, scaled by 1e18
    /// @dev If the debt is 0, `type(uint256).max` is returned
    function getHealthFactor() external view returns (uint256 healthFactor);

    /// @notice Supplies collateral assets to the lending pool
    /// @param amount Amount of assets to supply
    function addCollateral(uint256 amount) external;

    /// @notice Post-LeverageToken creation hook. Used for any validation logic or initialization after a LeverageToken
    /// is created using this adapter
    /// @param creator The address of the creator of the LeverageToken
    /// @param leverageToken The address of the LeverageToken that was created
    /// @dev This function is called in `LeverageManager.createNewLeverageToken` after the new LeverageToken is created
    function postLeverageTokenCreation(address creator, address leverageToken) external;

    /// @notice Withdraws collateral assets from the lending pool
    /// @param amount Amount of assets to withdraw
    function removeCollateral(uint256 amount) external;

    /// @notice Borrows assets from the lending pool
    /// @param amount Amount of assets to borrow
    function borrow(uint256 amount) external;

    /// @notice Repays debt to the lending pool
    /// @param amount Amount of assets of debt to repay
    function repay(uint256 amount) external;
}
