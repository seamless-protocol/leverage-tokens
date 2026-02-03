// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Aave v3 imports
import {IPool} from "@aave-v3-origin/contracts/interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from
    "@aave-v3-origin/contracts/misc/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IPoolAddressesProvider} from "@aave-v3-origin/contracts/interfaces/IPoolAddressesProvider.sol";

// Internal imports
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {ILeverageManager, ActionData} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageRouterV2} from "../interfaces/periphery/ILeverageRouterV2.sol";
import {IVeloraAdapter} from "../interfaces/periphery/IVeloraAdapter.sol";
import {IMulticallExecutor} from "../interfaces/periphery/IMulticallExecutor.sol";

/**
 * @title LeverageRouterV2
 * @dev The LeverageRouterV2 contract is an immutable periphery contract that facilitates the use of flash loans and swaps
 * to deposit and redeem equity from LeverageTokens. Supports both Morpho and Aave v3 flash loans.
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
 *
 * @custom:contact security@seamlessprotocol.com
 */
contract LeverageRouterV2 is ILeverageRouterV2, IFlashLoanSimpleReceiver, ReentrancyGuardTransient {
    /// @inheritdoc ILeverageRouterV2
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc ILeverageRouterV2
    IMorpho public immutable morpho;

    /// @inheritdoc IFlashLoanSimpleReceiver
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    /// @notice The Aave v3 Pool contract used for flash loans
    /// @dev Required by IFlashLoanSimpleReceiver interface
    /// @inheritdoc IFlashLoanSimpleReceiver
    IPool public immutable POOL;

    /// @notice Creates a new LeverageRouterV2
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    /// @param _aavePool The Aave v3 Pool contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho, IPool _aavePool) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        POOL = _aavePool;
        ADDRESSES_PROVIDER = _aavePool.ADDRESSES_PROVIDER();
    }

    /// @inheritdoc ILeverageRouterV2
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

    /// @inheritdoc ILeverageRouterV2
    function previewDeposit(ILeverageToken token, uint256 collateralFromSender)
        external
        view
        returns (ActionData memory previewData)
    {
        uint256 collateral = convertEquityToCollateral(token, collateralFromSender);
        return leverageManager.previewDeposit(token, collateral);
    }

    // ==================== Public Entry Points ====================

    /// @inheritdoc ILeverageRouterV2
    function deposit(
        ILeverageToken leverageToken,
        uint256 collateralFromSender,
        uint256 flashLoanAmount,
        uint256 minShares,
        IMulticallExecutor multicallExecutor,
        IMulticallExecutor.Call[] calldata swapCalls,
        FlashLoanSource flashLoanSource
    ) external nonReentrant {
        bytes memory depositData = abi.encode(
            DepositParams({
                sender: msg.sender,
                leverageToken: leverageToken,
                collateralFromSender: collateralFromSender,
                minShares: minShares,
                multicallExecutor: multicallExecutor,
                swapCalls: swapCalls
            })
        );

        address debtAsset = address(leverageManager.getLeverageTokenDebtAsset(leverageToken));

        if (flashLoanSource == FlashLoanSource.Morpho) {
            morpho.flashLoan(
                debtAsset,
                flashLoanAmount,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.Deposit, data: depositData}))
            );
        } else {
            POOL.flashLoanSimple(
                address(this),
                debtAsset,
                flashLoanAmount,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.Deposit, data: depositData})),
                0 // referralCode
            );
        }
    }

    /// @inheritdoc ILeverageRouterV2
    function redeem(
        ILeverageToken token,
        uint256 shares,
        uint256 minCollateralForSender,
        IMulticallExecutor multicallExecutor,
        IMulticallExecutor.Call[] calldata swapCalls,
        FlashLoanSource flashLoanSource
    ) external nonReentrant {
        uint256 debtRequired = leverageManager.previewRedeem(token, shares).debt;

        bytes memory redeemData = abi.encode(
            RedeemParams({
                sender: msg.sender,
                leverageToken: token,
                shares: shares,
                minCollateralForSender: minCollateralForSender,
                multicallExecutor: multicallExecutor,
                swapCalls: swapCalls
            })
        );

        address debtAsset = address(leverageManager.getLeverageTokenDebtAsset(token));

        if (flashLoanSource == FlashLoanSource.Morpho) {
            morpho.flashLoan(
                debtAsset,
                debtRequired,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.Redeem, data: redeemData}))
            );
        } else {
            POOL.flashLoanSimple(
                address(this),
                debtAsset,
                debtRequired,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.Redeem, data: redeemData})),
                0 // referralCode
            );
        }
    }

    /// @inheritdoc ILeverageRouterV2
    function redeemWithVelora(
        ILeverageToken token,
        uint256 shares,
        uint256 minCollateralForSender,
        IVeloraAdapter veloraAdapter,
        address augustus,
        IVeloraAdapter.Offsets calldata offsets,
        bytes calldata swapData,
        FlashLoanSource flashLoanSource
    ) external nonReentrant {
        uint256 debtRequired = leverageManager.previewRedeem(token, shares).debt;

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

        address debtAsset = address(leverageManager.getLeverageTokenDebtAsset(token));

        if (flashLoanSource == FlashLoanSource.Morpho) {
            morpho.flashLoan(
                debtAsset,
                debtRequired,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.RedeemWithVelora, data: redeemData}))
            );
        } else {
            POOL.flashLoanSimple(
                address(this),
                debtAsset,
                debtRequired,
                abi.encode(FlashLoanCallbackData({action: LeverageRouterAction.RedeemWithVelora, data: redeemData})),
                0 // referralCode
            );
        }
    }

    // ==================== Flash Loan Callbacks ====================

    /// @notice Morpho flash loan callback function
    /// @param loanAmount Amount of asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        FlashLoanCallbackData memory callbackData = abi.decode(data, (FlashLoanCallbackData));

        // Morpho has no premium, so totalRepayAmount equals loanAmount
        _handleFlashLoanCallback(callbackData.action, callbackData.data, loanAmount, loanAmount, address(morpho));
    }

    /// @inheritdoc IFlashLoanSimpleReceiver
    /// @notice Aave flash loan callback function
    function executeOperation(address, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        if (msg.sender != address(POOL)) revert Unauthorized();
        if (initiator != address(this)) revert Unauthorized();

        FlashLoanCallbackData memory callbackData = abi.decode(params, (FlashLoanCallbackData));

        uint256 totalRepayAmount = amount + premium;

        _handleFlashLoanCallback(callbackData.action, callbackData.data, amount, totalRepayAmount, address(POOL));

        return true;
    }

    // ==================== Internal Flash Loan Handler ====================

    /// @notice Routes flash loan callback to the appropriate handler
    /// @param action The action type (Deposit, Redeem, RedeemWithVelora)
    /// @param data Encoded parameters for the action
    /// @param loanAmount Amount flash loaned (excluding premium)
    /// @param totalRepayAmount Total amount to repay (loan + premium for Aave, loan for Morpho)
    /// @param flashLoanProvider Address to approve for repayment
    function _handleFlashLoanCallback(
        LeverageRouterAction action,
        bytes memory data,
        uint256 loanAmount,
        uint256 totalRepayAmount,
        address flashLoanProvider
    ) internal {
        if (action == LeverageRouterAction.Deposit) {
            DepositParams memory params = abi.decode(data, (DepositParams));
            _executeDeposit(params, loanAmount, totalRepayAmount, flashLoanProvider);
        } else if (action == LeverageRouterAction.Redeem) {
            RedeemParams memory params = abi.decode(data, (RedeemParams));
            _executeRedeem(params, loanAmount, totalRepayAmount, flashLoanProvider);
        } else if (action == LeverageRouterAction.RedeemWithVelora) {
            RedeemWithVeloraParams memory params = abi.decode(data, (RedeemWithVeloraParams));
            _executeRedeemWithVelora(params, loanAmount, totalRepayAmount, flashLoanProvider);
        }
    }

    // ==================== Internal Core Logic ====================

    /// @notice Executes the deposit into a LeverageToken and repays the flash loan
    /// @param params Params for the deposit into a LeverageToken
    /// @param loanAmount Amount of debt asset flash loaned (excluding premium)
    /// @param totalRepayAmount Total amount to repay (loan + premium for Aave, loan for Morpho)
    /// @param flashLoanProvider Address to approve for repayment
    function _executeDeposit(
        DepositParams memory params,
        uint256 loanAmount,
        uint256 totalRepayAmount,
        address flashLoanProvider
    ) internal {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.leverageToken);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.leverageToken);

        // Transfer the collateral from the sender for the deposit
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(collateralAsset, params.sender, address(this), params.collateralFromSender);

        // Swap the debt asset received from the flash loan to the collateral asset, used to deposit into the LeverageToken
        SafeERC20.safeTransfer(debtAsset, address(params.multicallExecutor), loanAmount);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = collateralAsset;
        tokens[1] = debtAsset;
        params.multicallExecutor.multicallAndSweep(params.swapCalls, tokens);

        // The sum of the collateral from the swap and the collateral from the sender
        uint256 totalCollateral = IERC20(collateralAsset).balanceOf(address(this));

        // Use the collateral from the swap and the collateral from the sender for the deposit into the LeverageToken
        SafeERC20.forceApprove(collateralAsset, address(leverageManager), totalCollateral);

        uint256 shares = leverageManager.deposit(params.leverageToken, totalCollateral, params.minShares).shares;

        // Transfer any surplus debt assets to the sender (after accounting for flash loan repayment)
        uint256 debtBalance = debtAsset.balanceOf(address(this));
        if (totalRepayAmount < debtBalance) {
            SafeERC20.safeTransfer(debtAsset, params.sender, debtBalance - totalRepayAmount);
        }

        // Transfer shares received from the deposit to the deposit sender
        SafeERC20.safeTransfer(params.leverageToken, params.sender, shares);

        // Approve flash loan provider to transfer debt assets to repay the flash loan
        SafeERC20.forceApprove(debtAsset, flashLoanProvider, totalRepayAmount);
    }

    /// @notice Executes the redeem from a LeverageToken and repays the flash loan
    /// @param params Params for the redeem from a LeverageToken
    /// @param loanAmount Amount of debt asset flash loaned (excluding premium)
    /// @param totalRepayAmount Total amount to repay (loan + premium for Aave, loan for Morpho)
    /// @param flashLoanProvider Address to approve for repayment
    function _executeRedeem(
        RedeemParams memory params,
        uint256 loanAmount,
        uint256 totalRepayAmount,
        address flashLoanProvider
    ) internal {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.leverageToken);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.leverageToken);

        // Transfer the shares from the sender
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(params.leverageToken, params.sender, address(this), params.shares);

        // Use the debt from the flash loan to redeem the shares from the sender
        SafeERC20.forceApprove(debtAsset, address(leverageManager), loanAmount);
        // slither-disable-next-line unused-return
        uint256 collateralWithdrawn =
            leverageManager.redeem(params.leverageToken, params.shares, params.minCollateralForSender).collateral;

        // Swap the collateral asset received from the redeem to the debt asset, used to repay the flash loan.
        SafeERC20.safeTransfer(collateralAsset, address(params.multicallExecutor), collateralWithdrawn);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = collateralAsset;
        tokens[1] = debtAsset;
        params.multicallExecutor.multicallAndSweep(params.swapCalls, tokens);

        // The remaining collateral after the arbitrary swap calls is available for the sender
        uint256 collateralForSender = collateralAsset.balanceOf(address(this));

        // The remaining debt after the arbitrary swap calls is available for the sender, minus
        // the amount of debt for repaying the flash loan (including premium if Aave)
        uint256 debtBalance = debtAsset.balanceOf(address(this));
        uint256 debtForSender = debtBalance > totalRepayAmount ? debtBalance - totalRepayAmount : 0;

        // Check slippage on collateral the sender receives
        if (collateralForSender < params.minCollateralForSender) {
            revert CollateralSlippageTooHigh(collateralForSender, params.minCollateralForSender);
        }

        // Transfer remaining collateral to the sender
        if (collateralForSender > 0) {
            SafeERC20.safeTransfer(collateralAsset, params.sender, collateralForSender);
        }

        // Transfer any remaining debt assets to the sender
        if (debtForSender > 0) {
            SafeERC20.safeTransfer(debtAsset, params.sender, debtForSender);
        }

        // Approve flash loan provider to spend the debt asset to repay the flash loan
        SafeERC20.forceApprove(debtAsset, flashLoanProvider, totalRepayAmount);
    }

    /// @notice Executes the redeem from a LeverageToken using Velora and repays the flash loan
    /// @param params Params for the redeem from a LeverageToken using Velora
    /// @param loanAmount Amount of debt asset flash loaned (excluding premium)
    /// @param totalRepayAmount Total amount to repay (loan + premium for Aave, loan for Morpho)
    /// @param flashLoanProvider Address to approve for repayment
    function _executeRedeemWithVelora(
        RedeemWithVeloraParams memory params,
        uint256 loanAmount,
        uint256 totalRepayAmount,
        address flashLoanProvider
    ) internal {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.leverageToken);
        IERC20 debtAsset = leverageManager.getLeverageTokenDebtAsset(params.leverageToken);

        // Transfer the shares from the sender
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(params.leverageToken, params.sender, address(this), params.shares);

        // Use the debt from the flash loan to redeem the shares from the sender
        SafeERC20.forceApprove(debtAsset, address(leverageManager), loanAmount);
        uint256 collateralWithdrawn =
            leverageManager.redeem(params.leverageToken, params.shares, params.minCollateralForSender).collateral;

        // Use the VeloraAdapter to swap the collateral asset received from the redeem to the debt asset.
        // For Aave, totalRepayAmount includes premium; for Morpho it equals loanAmount
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransfer(collateralAsset, address(params.veloraAdapter), collateralWithdrawn);
        uint256 collateralForSender = params.veloraAdapter.buy(
            params.augustus,
            params.swapData,
            address(collateralAsset),
            address(debtAsset),
            totalRepayAmount,
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

        // Approve flash loan provider to spend the debt asset to repay the flash loan
        SafeERC20.forceApprove(debtAsset, flashLoanProvider, totalRepayAmount);
    }
}
