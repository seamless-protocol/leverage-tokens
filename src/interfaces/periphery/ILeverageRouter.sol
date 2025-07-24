// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {ISwapAdapter} from "./ISwapAdapter.sol";
import {ActionData} from "../../types/DataTypes.sol";

interface ILeverageRouter {
    /// @notice Error thrown when the cost of a swap exceeds the maximum allowed cost
    /// @param actualCost The actual cost of the swap
    /// @param maxCost The maximum allowed cost of the swap
    error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);

    /// @notice Error thrown when the caller is not authorized to execute a function
    error Unauthorized();

    /// @notice The LeverageManager contract
    /// @return _leverageManager The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager _leverageManager);

    /// @notice The Morpho core protocol contract
    /// @return _morpho The Morpho core protocol contract
    function morpho() external view returns (IMorpho _morpho);

    /// @notice Previews mint function call and returns all required data
    /// @param token LeverageToken to preview mint for
    /// @param debt Debt to add to the LeverageToken
    /// @return previewData Preview data for mint
    ///         - collateral Amount of collateral that sender needs to approve the LeverageManager to spend,
    ///           this includes any fees
    ///         - debt Amount of debt that will be borrowed and sent to sender
    ///         - equity Amount of equity that will be used for minting shares before fees, denominated in collateral asset
    ///         - shares Amount of shares that will be minted to the sender
    ///         - tokenFee Amount of shares that will be charged for the mint that are given to the LeverageToken
    ///         - treasuryFee Amount of shares that will be charged for the mint that are given to the treasury
    function previewMintDebt(ILeverageToken token, uint256 debt)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Previews mint function call and returns all required data
    /// @param token LeverageToken to preview mint for
    /// @param equityInCollateralAsset Equity to mint LeverageTokens (shares) for, denominated in the collateral asset
    /// @return previewData Preview data for mint
    ///         - collateral Amount of collateral that sender needs to approve the LeverageManager to spend,
    ///           this includes any fees
    ///         - debt Amount of debt that will be borrowed and sent to sender
    ///         - equity Amount of equity that will be used for minting shares before fees, denominated in collateral asset
    ///         - shares Amount of shares that will be minted to the sender
    ///         - tokenFee Amount of shares that will be charged for the mint that are given to the LeverageToken
    ///         - treasuryFee Amount of shares that will be charged for the mint that are given to the treasury
    function previewMintEquity(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice Previews redeem function call and returns all required data
    /// @param token LeverageToken to preview redeem for
    /// @param equityInCollateralAsset Equity to receive by redeem denominated in collateral asset
    /// @return previewData Preview data for redeem
    ///         - collateral Amount of collateral that will be removed from the LeverageToken and sent to the sender
    ///         - debt Amount of debt that will be taken from sender and repaid to the LeverageToken
    ///         - equity Amount of equity that will be received for the redeem before fees, denominated in collateral asset
    ///         - shares Amount of shares that will be burned from sender
    ///         - tokenFee Amount of shares that will be charged for the redeem that are given to the LeverageToken
    ///         - treasuryFee Amount of shares that will be charged for the redeem that are given to the treasury
    function previewRedeemEquity(ILeverageToken token, uint256 equityInCollateralAsset)
        external
        view
        returns (ActionData memory previewData);

    /// @notice The swap adapter contract used to facilitate swaps
    /// @return _swapper The swap adapter contract
    function swapper() external view returns (ISwapAdapter _swapper);

    /// @notice Mint shares of a LeverageToken by adding equity
    /// @param token LeverageToken to mint shares of
    /// @param equityInCollateralAsset The amount of equity to mint LeverageToken shares for. Denominated in the collateral
    ///        asset of the LeverageToken
    /// @param minShares Minimum shares (LeverageTokens) to receive from the mint
    /// @param maxSwapCostInCollateralAsset The maximum amount of collateral from the sender to use to help repay the flash loan
    ///        due to the swap of debt to collateral being unfavorable
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    /// @dev Flash loans the collateral required to add the equity to the LeverageToken, receives debt, then swaps the debt to the
    ///      LeverageToken's collateral asset. The swapped assets and the sender's supplied collateral are used to repay the flash loan
    /// @dev The sender should approve the LeverageRouter to spend an amount of collateral assets greater than the equity being added
    ///      to facilitate the mint in the case that the mint requires additional collateral to cover swap slippage when swapping
    ///      debt to collateral to repay the flash loan. The approved amount should equal at least `equityInCollateralAsset + maxSwapCostInCollateralAsset`.
    ///      To see the preview of the mint, `LeverageRouter.leverageManager().previewMint(...)` can be used.
    function mint(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        uint256 minShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external;

    /// @notice Redeems equity of a LeverageToken by repaying debt and burning shares
    /// @param token LeverageToken to redeem
    /// @param equityInCollateralAsset The amount of equity to receive by redeeming LeverageToken. Denominated in the collateral
    ///        asset of the LeverageToken
    /// @param maxShares Maximum shares (LeverageTokens) to redeem
    /// @param maxSwapCostInCollateralAsset The maximum amount of equity to pay for the redeem of the LeverageToken
    ///        to use to help repay the debt flash loan due to the swap of debt to collateral being unfavorable
    /// @param swapContext Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)
    function redeem(
        ILeverageToken token,
        uint256 equityInCollateralAsset,
        uint256 maxShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external;
}
