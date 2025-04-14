// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IEtherFiL2ModeSyncPoolETH} from "../interfaces/periphery/IEtherFiL2ModeSyncPoolETH.sol";
import {IEtherFiLeverageRouter} from "../interfaces/periphery/IEtherFiLeverageRouter.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {IWETH9} from "../interfaces/periphery/IWETH9.sol";
import {ActionData, ExternalAction} from "../types/DataTypes.sol";

/**
 * @dev The EtherFiLeverageRouter contract is an immutable periphery contract that facilitates the use of Morpho flash loans
 * to deposit equity into LeverageTokens that use weETH as collateral and WETH as debt.
 *
 * The high-level deposit flow is as follows:
 *   1. The user calls `deposit` with the amount of weETH equity to deposit, and the minimum amount of shares (LeverageTokens)
 *      to receive.
 *   2. The EtherFiLeverageRouter will flash loan the additional required weETH from Morpho.
 *   3. The EtherFiLeverageRouter will use the flash loaned weETH and the weETH equity from the sender for the deposit into
 *      the LeverageToken, receiving LeverageTokens and WETH debt in return.
 *   4. The EtherFiLeverageRouter will unwrap the WETH debt to ETH and deposit the ETH into the EtherFi L2 Mode Sync Pool
 *      to obtain weETH.
 *   5. The weETH received from the EtherFi L2 Mode Sync Pool is used to repay the flash loan to Morpho.
 *   6. The EtherFiLeverageRouter will transfer the LeverageTokens and any remaining weETH to the sender.
 *
 * @dev Note: This router is intended to be used for LeverageTokens that use weETH as collateral and WETH as debt and will
 *   otherwise revert.
 */
contract EtherFiLeverageRouter is IEtherFiLeverageRouter {
    /// @notice Deposit related parameters to pass to the Morpho flash loan callback handler for deposits
    struct DepositParams {
        // LeverageToken to deposit into
        ILeverageToken token;
        // Amount of equity to deposit, denominated in the collateral asset (weETH)
        uint256 equityInCollateralAsset;
        // Minimum amount of shares (LeverageTokens) to receive
        uint256 minShares;
        // Address of the sender of the deposit, who will also receive the shares
        address sender;
    }

    /// @notice The ETH address per the EtherFi L2 Mode Sync Pool contract
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @inheritdoc IEtherFiLeverageRouter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc IEtherFiLeverageRouter
    IMorpho public immutable morpho;

    /// @inheritdoc IEtherFiLeverageRouter
    IEtherFiL2ModeSyncPoolETH public immutable etherFiL2ModeSyncPoolETH;

    /// @notice Creates a new LeverageRouter
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    /// @param _etherFiL2ModeSyncPoolETH The EtherFi L2 Mode Sync Pool contract
    constructor(
        ILeverageManager _leverageManager,
        IMorpho _morpho,
        IEtherFiL2ModeSyncPoolETH _etherFiL2ModeSyncPoolETH
    ) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        etherFiL2ModeSyncPoolETH = _etherFiL2ModeSyncPoolETH;
    }

    /// @inheritdoc IEtherFiLeverageRouter
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares) external {
        uint256 collateralToAdd = leverageManager.previewDeposit(token, equityInCollateralAsset).collateral;

        bytes memory depositData = abi.encode(
            DepositParams({
                token: token,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: minShares,
                sender: msg.sender
            })
        );

        // Flash loan the additional required weETH collateral (the sender must supply at least equityInCollateralAsset),
        // and pass the required data to the Morpho flash loan callback handler for the deposit.
        morpho.flashLoan(
            address(leverageManager.getLeverageTokenCollateralAsset(token)),
            collateralToAdd - equityInCollateralAsset,
            depositData
        );
    }

    /// @notice Morpho flash loan callback function
    /// @param loanAmount Amount of asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        DepositParams memory params = abi.decode(data, (DepositParams));
        _depositAndRepayMorphoFlashLoan(params, loanAmount);
    }

    /// @notice Executes the deposit of weETH equity into a LeverageToken and the swap of WETH debt assets to the weETH
    ///         collateral assets to repay the flash loan from Morpho
    /// @param params Params for the deposit of weETH equity into a LeverageToken
    /// @param collateralLoanAmount Amount of weETH collateral asset flash loaned
    function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal {
        IERC20 collateralAsset = leverageManager.getLeverageTokenCollateralAsset(params.token);
        IWETH9 debtAsset = IWETH9(address(leverageManager.getLeverageTokenDebtAsset(params.token)));

        // Transfer the weETHcollateral from the sender for the deposit
        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(collateralAsset, params.sender, address(this), params.equityInCollateralAsset);

        // Use the flash loaned weETH collateral and the weETH equity from the sender for the deposit into the LeverageToken
        SafeERC20.forceApprove(
            collateralAsset, address(leverageManager), collateralLoanAmount + params.equityInCollateralAsset
        );
        ActionData memory actionData =
            leverageManager.deposit(params.token, params.equityInCollateralAsset, params.minShares);

        // Unwrap the WETH debt asset received from the deposit
        debtAsset.withdraw(actionData.debt);

        // Deposit the ETH into the EtherFi L2 Mode Sync Pool to obtain weETH
        // Note: The EtherFi L2 Mode Sync Pool requires ETH to mint weETH. WETH is unsupported
        uint256 collateralFromEtherFi = etherFiL2ModeSyncPoolETH.deposit{value: actionData.debt}(
            ETH_ADDRESS, actionData.debt, collateralLoanAmount, address(0)
        );

        // Return any surplus collateral assets received from the EtherFi L2 Mode Sync Pool to the sender
        uint256 collateralAssetSurplus = collateralFromEtherFi - collateralLoanAmount;
        if (collateralAssetSurplus > 0) {
            SafeERC20.safeTransfer(collateralAsset, params.sender, collateralAssetSurplus);
        }

        // Transfer shares received from the deposit to the deposit sender
        SafeERC20.safeTransfer(params.token, params.sender, actionData.shares);

        // Approve morpho to transfer assets to repay the flash loan
        SafeERC20.forceApprove(collateralAsset, address(morpho), collateralLoanAmount);
    }

    receive() external payable {}
}
