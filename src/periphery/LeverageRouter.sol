// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";
import {ILeverageRouter} from "../interfaces/ILeverageRouter.sol";
import {DepositParams, MorphoCallbackData} from "../types/DataTypes.sol";

contract LeverageRouter is ILeverageRouter {
    /// @inheritdoc ILeverageRouter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc ILeverageRouter
    IMorpho public immutable morpho;

    /// @inheritdoc ILeverageRouter
    ISwapper public immutable swapper;

    constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapper _swapper) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        swapper = _swapper;
    }

    /// @inheritdoc ILeverageRouter
    function deposit(
        IStrategy strategy,
        uint256 collateralFromSender,
        uint256 equityInCollateralAsset,
        uint256 minShares,
        bytes calldata providerSwapData
    ) external returns (uint256 sharesReceived) {
        if (collateralFromSender < equityInCollateralAsset) revert InsufficientCollateral();

        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(strategy);
        collateralAsset.transferFrom(msg.sender, address(this), collateralFromSender);

        // Get required collateral amount for the equity amount being deposited into the strategy
        (uint256 shares, uint256 requiredCollateral, uint256 requiredDebt) =
            leverageManager.previewDeposit(strategy, equityInCollateralAsset);

        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(strategy);

        // Flash loan any additional required collateral from morpho
        if (requiredCollateral > equityInCollateralAsset) {
            morpho.flashLoan(
                address(collateralAsset),
                requiredCollateral - equityInCollateralAsset,
                abi.encode(
                    MorphoCallbackData({
                        action: IFeeManager.Action.Deposit,
                        actionData: abi.encode(
                            DepositParams({
                                strategy: strategy,
                                collateralAsset: collateralAsset,
                                debtAsset: debtAsset,
                                collateralFromSender: collateralFromSender,
                                equityInCollateralAsset: equityInCollateralAsset,
                                requiredCollateral: requiredCollateral,
                                requiredDebt: requiredDebt,
                                minShares: minShares,
                                receiver: msg.sender,
                                providerSwapData: providerSwapData
                            })
                        )
                    })
                )
            );
        } else {
            collateralAsset.approve(address(leverageManager), requiredCollateral);
            leverageManager.deposit(strategy, equityInCollateralAsset, minShares);

            SafeERC20.safeTransfer(strategy, msg.sender, shares);
            SafeERC20.safeTransfer(debtAsset, msg.sender, requiredDebt);

            uint256 collateralAssetSurplus = collateralFromSender - requiredCollateral;
            if (collateralAssetSurplus > 0) {
                SafeERC20.safeTransfer(collateralAsset, msg.sender, collateralAssetSurplus);
            }
        }

        return shares;
    }

    /// @notice Morpho flash loan callback function
    /// @dev Deposits equity into a strategy to receive debt assets to swap to the collateral asset to repay the flash loan
    /// @param collateralLoanAmount Amount of collateral asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 collateralLoanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        MorphoCallbackData memory callbackData = abi.decode(data, (MorphoCallbackData));

        if (callbackData.action == IFeeManager.Action.Deposit) {
            DepositParams memory params = abi.decode(callbackData.actionData, (DepositParams));
            _depositAndRepayMorphoFlashLoan(params, collateralLoanAmount);
        } else {
            revert InvalidAction();
        }
    }

    // Handles the deposit of equity into a strategy and the swap of debt assets to the collateral asset to repay the flash loan
    function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal {
        // Deposit equity into strategy using the flash loaned collateral and sender supplied equity
        params.collateralAsset.approve(address(leverageManager), params.requiredCollateral);
        uint256 sharesReceived =
            leverageManager.deposit(params.strategy, params.equityInCollateralAsset, params.minShares);

        // Swap the debt asset received from the deposit to the collateral asset, used to repay the flash loan
        params.debtAsset.approve(address(swapper), params.requiredDebt);
        uint256 toAmount = swapper.swap(
            params.debtAsset, params.collateralAsset, params.requiredDebt, collateralLoanAmount, params.providerSwapData
        );

        // The remaining sender supplied collateral is the amount of collateral that was not used to deposit the equity into the strategy,
        // which is the portion that is equal to the deposited equity amount. The rest of the collateral used for the deposit was from the flash loan
        uint256 remainingSenderSuppliedCollateral = params.collateralFromSender - params.equityInCollateralAsset;
        uint256 collateralAvailableToRepayFlashLoan = toAmount + remainingSenderSuppliedCollateral;
        if (collateralAvailableToRepayFlashLoan < collateralLoanAmount) revert InsufficientCollateralToRepayFlashLoan();

        // Return any surplus collateral asset not used to repay the flash loan to the deposit receiver
        uint256 collateralAssetSurplus = collateralAvailableToRepayFlashLoan - collateralLoanAmount;
        if (collateralAssetSurplus > 0) {
            SafeERC20.safeTransfer(params.collateralAsset, params.receiver, collateralAssetSurplus);
        }

        // Transfer shares received from the deposit to the receiver
        SafeERC20.safeTransfer(params.strategy, params.receiver, sharesReceived);

        // Approve morpho to transfer assets received from the swap to repay the flash loan
        params.collateralAsset.approve(address(morpho), collateralLoanAmount);
    }
}
