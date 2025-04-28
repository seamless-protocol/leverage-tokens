// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {LeverageRouterBase} from "./LeverageRouterBase.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ActionData} from "../types/DataTypes.sol";

/**
 * @dev The LeverageRouterMintBase contract is an abstract periphery contract that facilitates the use of Morpho flash loans
 * to mint equity into LeverageTokens.
 */
abstract contract LeverageRouterMintBase is LeverageRouterBase {
    /// @notice Mint related parameters to pass to the Morpho flash loan callback handler for mints
    struct MintParams {
        // LeverageToken to mint into
        ILeverageToken token;
        // Amount of equity to mint leverage token for, denominated in the collateral asset
        uint256 equityInCollateralAsset;
        // Minimum amount of shares (LeverageTokens) to receive
        uint256 minShares;
        // Address of the sender of the mint, who will also receive the shares
        address sender;
        // Any additional data to pass to the Morpho flash loan callback handler
        bytes additionalData;
    }

    /// @notice Creates a new LeverageRouterMint
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) LeverageRouterBase(_leverageManager, _morpho) {}

    /// @notice Executes the mint of LeverageToken and the logic to obtain collateral assets from debt assets
    ///         to repay the flash loan from Morpho
    /// @param params Params for the mint of a LeverageToken
    /// @param collateralLoanAmount Amount of collateral asset flash loaned
    function _mintAndRepayMorphoFlashLoan(MintParams memory params, uint256 collateralLoanAmount) internal virtual {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.token);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.token);

        // Mint equity into the LeverageToken using the flash loaned collateral and the equity from the sender
        ActionData memory actionData = _mint(params, collateralAsset, collateralLoanAmount);

        // Get collateral from debt received from the mint to repay the flash loan
        uint256 collateralFromDebt =
            _getCollateralFromDebt(debtAsset, actionData.debt, collateralLoanAmount, params.additionalData);

        // Return any surplus collateral assets received from the swap to the sender
        uint256 collateralAssetSurplus = collateralFromDebt - collateralLoanAmount;
        if (collateralAssetSurplus > 0) {
            SafeERC20.safeTransfer(collateralAsset, params.sender, collateralAssetSurplus);
        }

        // Transfer shares received from the mint to the mint sender
        SafeERC20.safeTransfer(params.token, params.sender, actionData.shares);

        // Approve morpho to transfer assets to repay the flash loan
        SafeERC20.forceApprove(collateralAsset, address(morpho), collateralLoanAmount);
    }

    /// @notice Performs the logic to mint equity into a LeverageToken, including the transfer of collateral from the sender,
    ///         the approval of the collateral asset, and the mint into the LeverageToken
    /// @param params Params for the mint of equity into a LeverageToken
    /// @param collateralLoanAmount The amount of collateral asset flash loaned for the mint
    /// @return actionData The ActionData for the mint
    function _mint(MintParams memory params, IERC20 collateralAsset, uint256 collateralLoanAmount)
        internal
        virtual
        returns (ActionData memory)
    {
        // Transfer the collateral from the sender for the mint
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(collateralAsset, params.sender, address(this), params.equityInCollateralAsset);

        // Use the flash loaned collateral and the equity from the sender for the mint
        SafeERC20.forceApprove(
            collateralAsset, address(leverageManager), collateralLoanAmount + params.equityInCollateralAsset
        );
        ActionData memory actionData =
            leverageManager.mint(params.token, params.equityInCollateralAsset, params.minShares);

        return actionData;
    }

    /// @notice Performs logic to obtain collateral assets from some amount of debt asset
    /// @param debtAsset The debt asset
    /// @param debtAmount The amount of debt to convert to collateral
    /// @param minCollateralAmount The minimum amount of collateral to obtain from the debt
    /// @param additionalData Any additional data to pass to the logic
    /// @return The amount of collateral assets obtained
    function _getCollateralFromDebt(
        IERC20 debtAsset,
        uint256 debtAmount,
        uint256 minCollateralAmount,
        bytes memory additionalData
    ) internal virtual returns (uint256) {}
}
