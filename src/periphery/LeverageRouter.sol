// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {ISwapAdapter} from "../interfaces/periphery/ISwapAdapter.sol";
import {ILeverageRouter} from "../interfaces/periphery/ILeverageRouter.sol";
import {ExternalAction} from "../types/DataTypes.sol";

contract LeverageRouter is ILeverageRouter {
    /// @notice Deposit related parameters to pass to the Morpho flash loan callback handler for deposits
    struct DepositParams {
        // Strategy to deposit into
        IStrategy strategy;
        // Amount of equity to deposit, denominated in the collateral asset
        uint256 equityInCollateralAsset;
        // Minimum amount of shares to receive
        uint256 minShares;
        // Maximum cost to the sender for the swap of debt to collateral during the deposit to repay the flash loan,
        // denominated in the collateral asset
        uint256 maxSwapCostInCollateralAsset;
        // Address of the sender of the deposit, who will also receive the shares
        address sender;
        // Swap context for the debt swap
        ISwapAdapter.SwapContext swapContext;
    }

    /// @notice Withdraw related parameters to pass to the Morpho flash loan callback handler for withdrawals
    struct WithdrawParams {
        // Strategy to withdraw from
        IStrategy strategy;
        // Amount of equity to withdraw, denominated in the collateral asset
        uint256 equityInCollateralAsset;
        // Maximum amount of shares to be burned during the withdrawal
        uint256 maxShares;
        // Maximum cost to the sender for the swap of debt to collateral during the withdrawal to repay the flash loan,
        // denominated in the collateral asset. This cost is applied to the equity being withdrawn
        uint256 maxSwapCostInCollateralAsset;
        // Address of the sender of the withdrawal, whose shares will be burned and the equity will be transferred to
        address sender;
        // Swap context for the debt swap
        ISwapAdapter.SwapContext swapContext;
    }

    /// @notice Morpho flash loan callback data to pass to the Morpho flash loan callback handler
    struct MorphoCallbackData {
        ExternalAction action;
        bytes data;
    }

    /// @inheritdoc ILeverageRouter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc ILeverageRouter
    IMorpho public immutable morpho;

    /// @inheritdoc ILeverageRouter
    ISwapAdapter public immutable swapper;

    /// @notice Creates a new LeverageRouter
    /// @param _leverageManager The Seamless LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    /// @param _swapper The Swapper contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapAdapter _swapper) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        swapper = _swapper;
    }

    /// @inheritdoc ILeverageRouter
    function deposit(
        IStrategy strategy,
        uint256 equityInCollateralAsset,
        uint256 minShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external {
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityInCollateralAsset);

        bytes memory depositData = abi.encode(
            DepositParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: minShares,
                maxSwapCostInCollateralAsset: maxSwapCostInCollateralAsset,
                sender: msg.sender,
                swapContext: swapContext
            })
        );

        // Flash loan the additional required collateral (the sender must supply at least equityInCollateralAsset),
        // and pass the required data to the Morpho flash loan callback handler for the deposit.
        morpho.flashLoan(
            address(leverageManager.getStrategyCollateralAsset(strategy)),
            collateralToAdd - equityInCollateralAsset,
            abi.encode(MorphoCallbackData({action: ExternalAction.Deposit, data: depositData}))
        );
    }

    /// @inheritdoc ILeverageRouter
    function withdraw(
        IStrategy strategy,
        uint256 equityInCollateralAsset,
        uint256 maxShares,
        uint256 maxSwapCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external {
        (, uint256 debtToRepay,,) = leverageManager.previewWithdraw(strategy, equityInCollateralAsset);

        bytes memory withdrawData = abi.encode(
            WithdrawParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                maxShares: maxShares,
                maxSwapCostInCollateralAsset: maxSwapCostInCollateralAsset,
                sender: msg.sender,
                swapContext: swapContext
            })
        );

        // Flash loan the debt asset required to repay the flash loan, and pass the required data to the Morpho flash loan callback handler for the withdrawal.
        morpho.flashLoan(
            address(leverageManager.getStrategyDebtAsset(strategy)),
            debtToRepay,
            abi.encode(MorphoCallbackData({action: ExternalAction.Withdraw, data: withdrawData}))
        );
    }

    /// @notice Morpho flash loan callback function
    /// @param loanAmount Amount of asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        MorphoCallbackData memory callbackData = abi.decode(data, (MorphoCallbackData));

        if (callbackData.action == ExternalAction.Deposit) {
            DepositParams memory params = abi.decode(callbackData.data, (DepositParams));
            _depositAndRepayMorphoFlashLoan(params, loanAmount);
        } else if (callbackData.action == ExternalAction.Withdraw) {
            WithdrawParams memory params = abi.decode(callbackData.data, (WithdrawParams));
            _withdrawAndRepayMorphoFlashLoan(params, loanAmount);
        }
    }

    /// @notice Executes the deposit of equity into a strategy and the swap of debt assets to the collateral asset
    /// to repay the flash loan from Morpho
    /// @param params Params for the deposit of equity into a strategy
    /// @param collateralLoanAmount Amount of collateral asset flash loaned
    function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal {
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(params.strategy);
        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(params.strategy);

        // Transfer the collateral from the sender for the deposit
        SafeERC20.safeTransferFrom(
            collateralAsset,
            params.sender,
            address(this),
            params.equityInCollateralAsset + params.maxSwapCostInCollateralAsset
        );

        // Use the flash loaned collateral and the equity from the sender for the deposit into the strategy
        collateralAsset.approve(address(leverageManager), collateralLoanAmount + params.equityInCollateralAsset);
        (, uint256 debtToBorrow, uint256 sharesReceived,) =
            leverageManager.deposit(params.strategy, params.equityInCollateralAsset, params.minShares);

        // Swap the debt asset received from the deposit to the collateral asset, used to repay the flash loan
        debtAsset.approve(address(swapper), debtToBorrow);
        uint256 swappedCollateralAmount = swapper.swapExactInput(
            debtAsset,
            debtToBorrow,
            0, // Set to zero because additional collateral from the sender is used to help repay the flash loan
            params.swapContext
        );

        // Transfer any surplus collateral assets to the sender
        uint256 assetsAvailableToRepayFlashLoan = swappedCollateralAmount + params.maxSwapCostInCollateralAsset;
        if (collateralLoanAmount > assetsAvailableToRepayFlashLoan) {
            revert MaxSwapCostExceeded(
                collateralLoanAmount - swappedCollateralAmount, params.maxSwapCostInCollateralAsset
            );
        } else {
            // Return any surplus collateral assets to the sender
            uint256 collateralAssetSurplus = assetsAvailableToRepayFlashLoan - collateralLoanAmount;
            if (collateralAssetSurplus > 0) {
                SafeERC20.safeTransfer(collateralAsset, params.sender, collateralAssetSurplus);
            }
        }

        // Transfer shares received from the deposit to the deposit sender
        SafeERC20.safeTransfer(params.strategy, params.sender, sharesReceived);

        // Approve morpho to transfer assets to repay the flash loan
        collateralAsset.approve(address(morpho), collateralLoanAmount);
    }

    /// @notice Executes the withdrawal of equity from a strategy and the swap of debt assets to the collateral asset
    /// to repay the flash loan from Morpho
    /// @param params Params for the withdrawal of equity from a strategy
    /// @param debtLoanAmount Amount of debt asset flash loaned
    function _withdrawAndRepayMorphoFlashLoan(WithdrawParams memory params, uint256 debtLoanAmount) internal {
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(params.strategy);
        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(params.strategy);

        // Transfer the shares from the sender
        SafeERC20.safeTransferFrom(params.strategy, params.sender, address(this), params.maxShares);

        // Withdraw the equity from the strategy
        debtAsset.approve(address(leverageManager), debtLoanAmount);
        (uint256 collateralReceived,,,) =
            leverageManager.withdraw(params.strategy, params.equityInCollateralAsset, params.maxShares);

        // Swap the collateral asset received from the withdrawal to the debt asset, used to repay the flash loan
        collateralAsset.approve(address(swapper), collateralReceived);
        uint256 collateralAmountSwapped =
            swapper.swapExactOutput(collateralAsset, debtLoanAmount, collateralReceived, params.swapContext);

        // Check if the amount of collateral swapped to repay the flash loan is greater than the allowed cost
        uint256 remainingCollateral = collateralReceived - collateralAmountSwapped;
        if (remainingCollateral < params.equityInCollateralAsset - params.maxSwapCostInCollateralAsset) {
            revert MaxSwapCostExceeded(
                params.equityInCollateralAsset - remainingCollateral, params.maxSwapCostInCollateralAsset
            );
        } else if (remainingCollateral > 0) {
            SafeERC20.safeTransfer(collateralAsset, params.sender, remainingCollateral);
        }

        // Approve morpho to transfer assets to repay the flash loan
        debtAsset.approve(address(morpho), debtLoanAmount);
    }
}
