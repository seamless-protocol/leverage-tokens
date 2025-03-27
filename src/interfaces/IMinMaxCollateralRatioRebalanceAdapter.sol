// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";

/// @title IMinMaxCollateralRatioRebalanceAdapter
/// @notice Interface for the MinMaxCollateralRatioRebalanceAdapter contract
interface IMinMaxCollateralRatioRebalanceAdapter {
    /// @notice Error thrown when min collateral ratio is too high
    error MinCollateralRatioTooHigh();

    /// @notice Event emitted when the collateral ratios are set
    event MinMaxCollateralRatioRebalanceAdapterInitialized(uint256 minCollateralRatio, uint256 maxCollateralRatio);

    /// @notice Returns the minimum collateral ratio for a leverage token
    /// @return minCollateralRatio Minimum collateral ratio for the leverage token
    function getLeverageTokenMinCollateralRatio() external view returns (uint256 minCollateralRatio);

    /// @notice Returns the maximum collateral ratio for a leverage token
    /// @return maxCollateralRatio Maximum collateral ratio for the leverage token
    function getLeverageTokenMaxCollateralRatio() external view returns (uint256 maxCollateralRatio);
}
