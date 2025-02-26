// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

// Internal imports
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {ISwapAdapter} from "../interfaces/periphery/ISwapAdapter.sol";
import {ILeverageRouter} from "../interfaces/periphery/ILeverageRouter.sol";
import {ExternalAction} from "../types/DataTypes.sol";

contract LeverageRouter is ILeverageRouter {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;

    /// @notice Deposit related parameters to pass to the Morpho flash loan callback handler for deposits
    struct DepositParams {
        // Strategy to deposit into
        IStrategy strategy;
        // Amount of equity to deposit, denominated in the collateral asset
        uint256 equityInCollateralAsset;
        // Minimum amount of shares to receive
        uint256 minShares;
        // Maximum amount of collateral asset to use for the deposit of equity, denominated in the collateral asset
        uint256 maxDepositCostInCollateralAsset;
        // Address of the sender of the deposit, who will also receive the shares
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
        uint256 maxDepositCostInCollateralAsset,
        ISwapAdapter.SwapContext memory swapContext
    ) external {
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityInCollateralAsset);

        bytes memory depositData = abi.encode(
            DepositParams({
                strategy: strategy,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: minShares,
                maxDepositCostInCollateralAsset: maxDepositCostInCollateralAsset,
                sender: msg.sender,
                swapContext: swapContext
            })
        );

        // Flash loan the collateral to add, and pass the required data to the Morpho flash loan callback handler for the deposit
        morpho.flashLoan(
            address(leverageManager.getStrategyCollateralAsset(strategy)),
            collateralToAdd,
            abi.encode(MorphoCallbackData({action: ExternalAction.Deposit, data: depositData}))
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
        }
    }

    /// @notice Executes the deposit of equity into a strategy and the swap of debt assets to the collateral asset
    /// to repay the flash loan from Morpho
    /// @param params Params for the deposit of equity into a strategy
    /// @param collateralLoanAmount Amount of collateral asset flash loaned
    function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal {
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(params.strategy);
        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(params.strategy);

        // Use the flash loaned collateral for the deposit
        collateralAsset.approve(address(leverageManager), collateralLoanAmount);
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

        // Transfer additional collateral from the sender to repay the flash loan in the case that the debt swap did not
        // result in enough collateral to repay the flash loan
        if (swappedCollateralAmount < collateralLoanAmount) {
            uint256 senderCollateralRequired = collateralLoanAmount - swappedCollateralAmount;

            // Check if the maximum cost specified by the sender is less than the amount of collateral needed to help repay the flash loan
            if (params.maxDepositCostInCollateralAsset < senderCollateralRequired) {
                revert MaxDepositCostExceeded(params.maxDepositCostInCollateralAsset, senderCollateralRequired);
            }

            SafeERC20.safeTransferFrom(collateralAsset, params.sender, address(this), senderCollateralRequired);
        } else {
            // Return any surplus collateral asset received from the swap that was not used to repay the flash loan to the deposit sender
            uint256 collateralAssetSurplus = swappedCollateralAmount - collateralLoanAmount;
            if (collateralAssetSurplus > 0) {
                SafeERC20.safeTransfer(collateralAsset, params.sender, collateralAssetSurplus);
            }
        }

        // Transfer shares received from the deposit to the deposit sender
        SafeERC20.safeTransfer(params.strategy, params.sender, sharesReceived);

        // Approve morpho to transfer assets to repay the flash loan
        collateralAsset.approve(address(morpho), collateralLoanAmount);
    }
}
