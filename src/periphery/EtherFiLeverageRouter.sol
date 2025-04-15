// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IEtherFiL2ModeSyncPool} from "../interfaces/periphery/IEtherFiL2ModeSyncPool.sol";
import {IEtherFiLeverageRouter} from "../interfaces/periphery/IEtherFiLeverageRouter.sol";
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {IWETH9} from "../interfaces/periphery/IWETH9.sol";
import {LeverageRouterDepositBase} from "./LeverageRouterDepositBase.sol";

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
contract EtherFiLeverageRouter is LeverageRouterDepositBase, IEtherFiLeverageRouter {
    /// @notice The ETH address per the EtherFi L2 Mode Sync Pool contract
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @inheritdoc IEtherFiLeverageRouter
    IEtherFiL2ModeSyncPool public immutable etherFiL2ModeSyncPool;

    /// @notice Creates a new EtherFiLeverageRouter
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    /// @param _etherFiL2ModeSyncPool The EtherFi L2 Mode Sync Pool contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho, IEtherFiL2ModeSyncPool _etherFiL2ModeSyncPool)
        LeverageRouterDepositBase(_leverageManager, _morpho)
    {
        etherFiL2ModeSyncPool = _etherFiL2ModeSyncPool;
    }

    /// @inheritdoc IEtherFiLeverageRouter
    function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares) external {
        uint256 collateralToAdd = leverageManager.previewDeposit(token, equityInCollateralAsset).collateral;

        bytes memory depositData = abi.encode(
            DepositParams({
                token: token,
                equityInCollateralAsset: equityInCollateralAsset,
                minShares: minShares,
                sender: msg.sender,
                additionalData: ""
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

    /// @notice Performs logic to obtain weETH collateral from WETH debt
    /// @param weth The WETH contract
    /// @param wethAmount The amount of WETH debt to convert to weETH collateral
    /// @param weethLoanAmount The amount of weETH flash loaned
    /// @return The amount of weETH collateral obtained
    function _getCollateralFromDebt(
        IERC20 weth,
        uint256 wethAmount,
        uint256 weethLoanAmount,
        bytes memory /* additionalData */
    ) internal override returns (uint256) {
        IWETH9(address(weth)).withdraw(wethAmount);

        // Deposit the ETH into the EtherFi L2 Mode Sync Pool to obtain weETH
        // Note: The EtherFi L2 Mode Sync Pool requires ETH to mint weETH. WETH is unsupported
        uint256 collateralFromEtherFi =
            etherFiL2ModeSyncPool.deposit{value: wethAmount}(ETH_ADDRESS, wethAmount, weethLoanAmount, address(0));

        return collateralFromEtherFi;
    }
}
