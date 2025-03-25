// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IRebalanceModule} from "src/interfaces/IRebalanceModule.sol";

/// @title ISeamlessRebalanceModule
/// @notice Interface for the SeamlessRebalanceModule contract
interface ISeamlessRebalanceModule is IRebalanceModule {
    /// @notice Error thrown when collateral ratios are already set
    error CollateralRatiosAlreadySet();

    /// @notice Error thrown when min collateral ratio is too high
    error MinCollateralRatioTooHigh();

    /// @notice Event emitted when rebalancer is set
    event IsRebalancerSet(address indexed rebalancer, bool isRebalancer);

    /// @notice Event emitted when collateral ratios are set
    event LeverageTokenCollateralRatiosSet(
        ILeverageToken indexed token, uint256 minCollateralRatio, uint256 maxCollateralRatio
    );

    /// @notice Returns whether the address is a rebalancer
    /// @param rebalancer Address to check
    /// @return isRebalancer Whether the address is a rebalancer
    function getIsRebalancer(address rebalancer) external view returns (bool isRebalancer);

    /// @notice Returns the minimum collateral ratio for a leverage token
    /// @param token Leverage token to get the minimum collateral ratio for
    /// @return minCollateralRatio Minimum collateral ratio for the leverage token
    function getLeverageTokenMinCollateralRatio(ILeverageToken token)
        external
        view
        returns (uint256 minCollateralRatio);

    /// @notice Returns the maximum collateral ratio for a leverage token
    /// @param token Leverage token to get the maximum collateral ratio for
    /// @return maxCollateralRatio Maximum collateral ratio for the leverage token
    function getLeverageTokenMaxCollateralRatio(ILeverageToken token)
        external
        view
        returns (uint256 maxCollateralRatio);

    /// @notice Sets whether the address is a rebalancer
    /// @param rebalancer Address to set
    /// @param isRebalancer Whether the address is a rebalancer
    function setIsRebalancer(address rebalancer, bool isRebalancer) external;

    /// @notice Sets the minimum and maximum collateral ratios for a leverage token
    /// @param token Leverage token to set the collateral ratios for
    /// @param minCollateralRatio Minimum collateral ratio for the leverage token
    /// @param maxCollateralRatio Maximum collateral ratio for the leverage token
    /// @dev Revert if collateral ratios are already set
    function setLeverageTokenCollateralRatios(
        ILeverageToken token,
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) external;
}
