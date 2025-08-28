// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ISwapAdapter} from "../interfaces/periphery/ISwapAdapter.sol";
import {ILeverageRouter} from "../interfaces/periphery/ILeverageRouter.sol";
import {IVeloraAdapter} from "../interfaces/periphery/IVeloraAdapter.sol";
import {ActionData, ActionDataV2, ExternalAction} from "../types/DataTypes.sol";

/**
 * @dev The LeverageRouter contract is an immutable periphery contract that facilitates the use of flash loans and a swaps
 * to deposit and redeem equity from LeverageTokens.
 *
 * The high-level deposit flow is as follows:
 *   1. The sender calls `deposit` with the amount of collateral from the sender to deposit, the amount of debt to flash loan
 *      (which will be swapped to collateral), the minimum amount of shares to receive, and the calldata to execute for
 *      the swap of the flash loaned debt to collateral
 *   2. The LeverageRouter will flash loan the debt asset amount and execute the calldata to swap it to collateral
 *   3. The LeverageRouter will use the collateral from the swapped debt and the collateral from the sender for the deposit
 *      into the LeverageToken, receiving LeverageToken shares and debt in return
 *   4. The LeverageRouter will use the debt received from the deposit to repay the flash loan
 *   6. The LeverageRouter will transfer the LeverageToken shares and any surplus debt assets to the sender
 *
 * The high-level redeem flow is the same as the deposit flow, but in reverse.
 */
contract LeverageRouter is ILeverageRouter {
    /// @inheritdoc ILeverageRouter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc ILeverageRouter
    IMorpho public immutable morpho;

    /// @notice Creates a new LeverageRouter
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) {
        leverageManager = _leverageManager;
        morpho = _morpho;
    }

    /// @inheritdoc ILeverageRouter
    function convertEquityToCollateral(ILeverageToken token, uint256 equityInCollateralAsset)
        public
        view
        returns (uint256 collateral)
    {
        uint256 collateralRatio = leverageManager.getLeverageTokenState(token).collateralRatio;
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(token);
        uint256 baseRatio = leverageManager.BASE_RATIO();

        if (lendingAdapter.getCollateral() == 0 && lendingAdapter.getDebt() == 0) {
            uint256 initialCollateralRatio = leverageManager.getLeverageTokenInitialCollateralRatio(token);
            collateral = Math.mulDiv(
                equityInCollateralAsset, initialCollateralRatio, initialCollateralRatio - baseRatio, Math.Rounding.Ceil
            );
        } else if (collateralRatio == type(uint256).max) {
            collateral = equityInCollateralAsset;
        } else {
            collateral =
                Math.mulDiv(equityInCollateralAsset, collateralRatio, collateralRatio - baseRatio, Math.Rounding.Ceil);
        }

        return collateral;
    }

    /// @inheritdoc ILeverageRouter
    function previewDeposit(ILeverageToken token, uint256 collateralFromSender)
        external
        view
        returns (ActionDataV2 memory previewData)
    {
        uint256 collateral = convertEquityToCollateral(token, collateralFromSender);
        return leverageManager.previewDeposit(token, collateral);
    }

    /// @inheritdoc ILeverageRouter
    function deposit(
        ILeverageToken leverageToken,
        uint256 collateralFromSender,
        uint256 flashLoanAmount,
        uint256 minShares,
        Call[] calldata swapCalls
    ) external {
        bytes memory depositData = abi.encode(
            DepositParams({
                sender: msg.sender,
                leverageToken: leverageToken,
                collateralFromSender: collateralFromSender,
                minShares: minShares,
                swapCalls: swapCalls
            })
        );

        morpho.flashLoan(
            address(leverageManager.getLeverageTokenDebtAsset(leverageToken)),
            flashLoanAmount,
            abi.encode(MorphoCallbackData({action: ExternalAction.Mint, data: depositData}))
        );
    }

    /// @inheritdoc ILeverageRouter
    function redeemWithVelora(
        ILeverageToken token,
        uint256 shares,
        uint256 minCollateralForSender,
        IVeloraAdapter veloraAdapter,
        address augustus,
        IVeloraAdapter.Offsets calldata offsets,
        bytes calldata swapData
    ) external {
        uint256 debtRequired = leverageManager.previewRedeemV2(token, shares).debt;

        bytes memory redeemData = abi.encode(
            RedeemWithVeloraParams({
                sender: msg.sender,
                leverageToken: token,
                shares: shares,
                minCollateralForSender: minCollateralForSender,
                veloraAdapter: veloraAdapter,
                augustus: augustus,
                offsets: offsets,
                swapData: swapData
            })
        );

        morpho.flashLoan(
            address(leverageManager.getLeverageTokenDebtAsset(token)),
            debtRequired,
            abi.encode(MorphoCallbackData({action: ExternalAction.Redeem, data: redeemData}))
        );
    }

    /// @notice Morpho flash loan callback function
    /// @param loanAmount Amount of asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        MorphoCallbackData memory callbackData = abi.decode(data, (MorphoCallbackData));

        if (callbackData.action == ExternalAction.Mint) {
            DepositParams memory params = abi.decode(callbackData.data, (DepositParams));
            _depositAndRepayMorphoFlashLoan(params, loanAmount);
        } else if (callbackData.action == ExternalAction.Redeem) {
            RedeemWithVeloraParams memory params = abi.decode(callbackData.data, (RedeemWithVeloraParams));
            _redeemWithVeloraAndRepayMorphoFlashLoan(params, loanAmount);
        }
    }

    /// @notice Executes the deposit into a LeverageToken by flash loaning the debt asset, swapping it to collateral,
    /// depositing into the LeverageToken with the sender's collateral, and using the resulting debt to repay the flash loan.
    /// Any surplus debt assets after repaying the flash loan are given to the sender.
    /// @param params Params for the deposit into a LeverageToken
    /// @param debtLoan Amount of debt asset flash loaned
    function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 debtLoan) internal {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.leverageToken);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.leverageToken);

        // Transfer the collateral from the sender for the deposit
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(collateralAsset, params.sender, address(this), params.collateralFromSender);

        // Swap the debt asset received from the flash loan to the collateral asset, used to deposit into the LeverageToken
        for (uint256 i = 0; i < params.swapCalls.length; i++) {
            // slither-disable-next-line unused-return
            Address.functionCallWithValue(
                params.swapCalls[i].target, params.swapCalls[i].data, params.swapCalls[i].value
            );
        }

        // The sum of the collateral from the swap and the collateral from the sender
        uint256 totalCollateral = IERC20(collateralAsset).balanceOf(address(this));

        // Use the collateral from the swap and the collateral from the sender for the deposit into the LeverageToken
        SafeERC20.forceApprove(collateralAsset, address(leverageManager), totalCollateral);

        ActionDataV2 memory actionData =
            leverageManager.deposit(params.leverageToken, totalCollateral, params.minShares);

        // Transfer any surplus debt assets to the sender
        if (debtLoan < actionData.debt) {
            SafeERC20.safeTransfer(debtAsset, params.sender, actionData.debt - debtLoan);
        }

        // Transfer shares received from the deposit to the deposit sender
        SafeERC20.safeTransfer(params.leverageToken, params.sender, actionData.shares);

        // Approve morpho to transfer debt assets to repay the flash loan
        // Note: if insufficient debt is available to repay the flash loan, the transaction will revert when Morpho
        // attempts to transfer the debt assets to repay the flash loan
        SafeERC20.forceApprove(debtAsset, address(morpho), debtLoan);
    }

    /// @notice Executes the redeem from a LeverageToken by flash loaning the debt asset, swapping the collateral asset
    /// to the debt asset using Velora, using the resulting debt to repay the flash loan, and transferring the remaining
    /// collateral asset to the sender
    /// @param params Params for the redeem from a LeverageToken using Velora
    /// @param debtLoanAmount Amount of debt asset flash loaned
    function _redeemWithVeloraAndRepayMorphoFlashLoan(RedeemWithVeloraParams memory params, uint256 debtLoanAmount)
        internal
    {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.leverageToken);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.leverageToken);

        // Transfer the shares from the sender
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(params.leverageToken, params.sender, address(this), params.shares);

        // Use the debt from the flash loan to redeem the shares from the sender
        SafeERC20.forceApprove(debtAsset, address(leverageManager), debtLoanAmount);
        uint256 collateralWithdrawn =
            leverageManager.redeemV2(params.leverageToken, params.shares, params.minCollateralForSender).collateral;

        // Use the VeloraAdapter to swap the collateral asset received from the redeem to the debt asset, used to repay the flash loan.
        // The excess collateral asset sent back to this LeverageRouter is for the sender of the redeem
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransfer(collateralAsset, address(params.veloraAdapter), collateralWithdrawn);
        uint256 collateralForSender = params.veloraAdapter.buy(
            params.augustus,
            params.swapData,
            address(collateralAsset),
            address(debtAsset),
            debtLoanAmount,
            params.offsets,
            address(this)
        );

        // Check slippage
        if (collateralForSender < params.minCollateralForSender) {
            revert CollateralSlippageTooHigh(collateralForSender, params.minCollateralForSender);
        }

        // Transfer remaining collateral to the sender
        if (collateralForSender > 0) {
            SafeERC20.safeTransfer(collateralAsset, params.sender, collateralForSender);
        }

        // Approve Morpho to spend the debt asset to repay the flash loan
        SafeERC20.forceApprove(debtAsset, address(morpho), debtLoanAmount);
    }

    receive() external payable {}
}
