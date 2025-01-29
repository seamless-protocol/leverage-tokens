// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "./ILeverageManager.sol";
import {IStrategy} from "./IStrategy.sol";
import {ISwapper} from "./ISwapper.sol";

interface ILeverageRouter {
    /// @notice Error thrown when insufficient collateral is provided for an action
    error InsufficientCollateral();

    /// @notice Error thrown when the collateral provided plus the swapped debt is less than the required collateral to repay the flash loan
    error InsufficientCollateralToRepayFlashLoan();

    /// @notice Error thrown when the caller is not authorized to call a function
    error Unauthorized();

    /// @notice The Seamless ilm-v2 LeverageManager contract
    /// @return leverageManager The Seamless ilm-v2 LeverageManager contract
    function leverageManager() external view returns (ILeverageManager leverageManager);

    /// @notice The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice The swapper contract used to facilitate swaps
    function swapper() external view returns (ISwapper _swapper);

    /// @notice Deposit equity into a strategy
    /// @dev The LeverageRouter must be approved to spend `collateralFromSender` of the strategy's collateral asset
    /// @dev `collateralFromSender` should be greater than `equityInCollateralAsset` to facilitate the deposit in the case that
    ///      the deposit requires additional collateral to cover swap slippage when converting debt to collateral to repay the flash loan.
    ///      Otherwise, it should be equal to `equityInCollateralAsset`
    /// @param strategy Strategy to deposit equity into
    /// @param collateralFromSender The amount of collateral asset to deposit from the sender
    /// @param equityInCollateralAsset The min amount of equity in the collateral asset to deposit into the strategy
    /// @param minShares Minimum shares to receive from the deposit
    /// @param providerSwapData Swap data to use for the swap using the set provider
    /// @return sharesReceived The amount of shares received from the deposit
    function deposit(
        IStrategy strategy,
        uint256 collateralFromSender,
        uint256 equityInCollateralAsset,
        uint256 minShares,
        bytes calldata providerSwapData
    ) external returns (uint256 sharesReceived);
}
