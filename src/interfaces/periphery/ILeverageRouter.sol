// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {ISwapAdapter} from "./ISwapAdapter.sol";

interface ILeverageRouter {
    /// @notice Error thrown when the cost of a swap exceeds the maximum allowed cost
    error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);

    /// @notice Error thrown when the caller is not authorized to call a function
    error Unauthorized();

    /// @notice The Seamless LeverageManager contract
    /// @return _leverageManager The Seamless LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice The swap adapter contract used to facilitate swaps
    /// @return _swapper The swap adapter contract
    function swapper() external view returns (ISwapAdapter _swapper);

    /// @notice Deposit equity into a leverage token
    /// @param token Leverage token to deposit equity into
    /// @param equityInCollateralAsset The amount of equity to deposit into the leverage token. Denominated in the collateral
    ///        asset of the leverage token
    /// @param minShares Minimum shares to receive from the deposit
    /// @param maxSwapCostInCollateralAsset The maximum amount of collateral from the sender to use to help repay the flash loan
    ///        due to the swap of debt to collateral being unfavorable
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    /// @dev Flash loans the collateral required to add the equity to the leverage token, receives debt, then swaps the debt to the
    ///      leverage token's collateral asset. The swapped assets and the sender's supplied collateral are used to repay the flash loan
    /// @dev The sender should approve the LeverageRouter to spend an amount of collateral assets greater than the equity being added
    ///      to facilitate the deposit in the case that the deposit requires additional collateral to cover swap slippage when swapping
    ///      debt to collateral to repay the flash loan. The approved amount should equal at least `equityInCollateralAsset + maxSwapCostInCollateralAsset`.
    ///      To see the preview of the deposit, `LeverageRouter.leverageManager().previewDeposit(...)` can be used.
    function deposit(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        uint256 minShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external;

    /// @notice Withdraw equity from a leverage token
    /// @param token Leverage token to withdraw equity from
    /// @param equityInCollateralAsset The amount of equity to withdraw from the leverage token. Denominated in the collateral
    ///        asset of the leverage token
    /// @param maxShares Maximum shares to burn for the withdrawal
    /// @param maxSwapCostInCollateralAsset The maximum amount of equity received from the withdrawal from the leverage token
    ///        to use to help repay the debt flash loan due to the swap of debt to collateral being unfavorable
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    function withdraw(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        uint256 maxShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external;
}
