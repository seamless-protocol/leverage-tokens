// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IMorphoFlashLoanCallback} from "@morpho-blue/interfaces/IMorphoCallbacks.sol";

// Internal imports
import {ILeverageManager} from "./ILeverageManager.sol";
import {IStrategy} from "./IStrategy.sol";
import {ActionType, RebalanceAction, TokenTransfer} from "../types/DataTypes.sol";

/// @title IRebalanceModuleLIFI
/// @notice Interface for the RebalanceModuleLIFI contract that handles rebalancing operations using LIFI for swaps
interface IRebalanceModuleLIFI is IMorphoFlashLoanCallback {
    /// @notice Error thrown when swap fails
    error SwapFailed();

    /// @notice Error thrown when caller is not authorized
    error Unauthorized();

    /// @notice Event emitted when rebalance is executed
    /// @param strategy The strategy being rebalanced
    /// @param collateralToAdd Amount of collateral added
    /// @param debtToBorrow Amount of debt borrowed
    /// @param providerSwapData Encoded swap data for LIFI
    event RebalanceExecuted(
        IStrategy indexed strategy, uint256 collateralToAdd, uint256 debtToBorrow, bytes providerSwapData
    );

    /// @notice Returns the Morpho contract
    /// @return The Morpho contract interface
    function morpho() external view returns (IMorpho);

    /// @notice Returns the LeverageManager contract
    /// @return The LeverageManager contract interface
    function leverageManager() external view returns (ILeverageManager);

    /// @notice Returns the LIFI contract address
    /// @return The LIFI contract address
    function lifi() external view returns (address);

    /// @notice Executes a rebalance operation for an over-collateralized position
    /// @dev Takes a flash loan in collateral token, adds it as collateral, borrows debt, and swaps debt for collateral
    /// @param strategy The strategy to rebalance
    /// @param collateralToAdd Amount of collateral to add
    /// @param debtToBorrow Amount of debt to borrow
    /// @param providerSwapData Encoded swap data for LIFI to swap debt for collateral
    function rebalanceOverCollateralized(
        IStrategy strategy,
        uint256 collateralToAdd,
        uint256 debtToBorrow,
        bytes memory providerSwapData
    ) external;
}
