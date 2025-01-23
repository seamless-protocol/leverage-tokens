// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract LeverageRouter {
    ILeverageManager public immutable leverageManager;

    IMorpho public immutable morpho;

    ISwapper public immutable swapper;

    error Unauthorized();

    struct DepositParams {
        IStrategy strategy;
        IERC20 collateralAsset;
        IERC20 debtAsset;
        uint256 equityInCollateralAsset;
        uint256 requiredCollateral;
        uint256 requiredDebt;
        address receiver;
        bytes providerSwapData;
    }

    constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapper _swapper) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        swapper = _swapper;
    }

    /// @notice Get the current swap provider
    /// @return provider Current swap provider
    function getSwapProvider() external view returns (ISwapper.Provider) {
        return swapper.provider();
    }

    /// @notice Preview total collateral and debt required for a deposit of equity into a strategy
    /// @dev This function is useful for generating swap aggregator calldata required for a deposit.
    ///      For example, if the LeverageRouter's Swapper is using LiFi for swaps, the caller needs to pass in calldata for the LiFi
    ///      swap. This calldata is obtained off-chain by the LiFi API, which requires knowledge of the amount of debt to swap
    ///      to the collateral asset for repaying the flash loan used to deposit the equity into the strategy.
    /// @param strategy Strategy to preview collateral and debt for
    /// @param equityInCollateralAsset Equity in collateral asset to preview collateral and debt for
    /// @return collateral Collateral required
    /// @return debt Debt required
    function previewCollateralAndDebtRequiredForDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        external
        view
        returns (uint256 collateral, uint256 debt)
    {
        return leverageManager.getStrategyCollateralAndDebtForEquity(
            strategy, equityInCollateralAsset, IFeeManager.Action.Deposit
        );
    }

    /// @notice Deposit equity into a strategy
    /// @dev The LeverageRouter must be approved to spend `equityInCollateralAsset` of the strategy's collateral asset
    /// @param strategy Strategy to deposit equity into
    /// @param equityInCollateralAsset Equity in collateral asset to deposit
    /// @param providerSwapData Swap data to use for the swap using the set provider
    function deposit(IStrategy strategy, uint256 equityInCollateralAsset, bytes calldata providerSwapData) external {
        ILeverageManager _leverageManager = leverageManager;
        IERC20 collateralAsset = _leverageManager.getStrategyCollateralAsset(strategy);

        collateralAsset.transferFrom(msg.sender, address(this), equityInCollateralAsset);

        // Get required collateral amount for the equity amount being deposited into the strategy
        (uint256 requiredCollateral, uint256 requiredDebt) = _leverageManager.getStrategyCollateralAndDebtForEquity(
            strategy, equityInCollateralAsset, IFeeManager.Action.Deposit
        );

        IERC20 debtAsset = _leverageManager.getStrategyDebtAsset(strategy);

        // Flash loan any additional required collateral from morpho
        if (requiredCollateral > equityInCollateralAsset) {
            morpho.flashLoan(
                address(collateralAsset),
                requiredCollateral - equityInCollateralAsset,
                abi.encode(
                    DepositParams({
                        strategy: strategy,
                        collateralAsset: collateralAsset,
                        debtAsset: debtAsset,
                        equityInCollateralAsset: equityInCollateralAsset,
                        requiredCollateral: requiredCollateral,
                        requiredDebt: requiredDebt,
                        receiver: msg.sender,
                        providerSwapData: providerSwapData
                    })
                )
            );
        } else {
            uint256 minShares = _leverageManager.convertEquityToShares(strategy, equityInCollateralAsset);
            uint256 sharesReceived = _leverageManager.deposit(strategy, equityInCollateralAsset, minShares);
            SafeERC20.safeTransfer(strategy, msg.sender, sharesReceived);
            SafeERC20.safeTransfer(debtAsset, msg.sender, requiredDebt);
        }
    }

    /// @notice Morpho flash loan callback function
    /// @dev Deposits equity into a strategy to receive debt assets to swap to the collateral asset to repay the flash loan
    /// @param collateralLoanAmount Amount of collateral asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`
    function onMorphoFlashLoan(uint256 collateralLoanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        DepositParams memory params = abi.decode(data, (DepositParams));
        ILeverageManager _leverageManager = leverageManager;

        // Convert equity to expected strategy shares
        uint256 minShares = _leverageManager.convertEquityToShares(params.strategy, params.equityInCollateralAsset);

        // Deposit equity into strategy and give receiver the minted shares and debt assets
        params.collateralAsset.approve(address(_leverageManager), params.requiredCollateral);
        uint256 sharesReceived = _leverageManager.deposit(params.strategy, params.equityInCollateralAsset, minShares);
        SafeERC20.safeTransfer(params.strategy, params.receiver, sharesReceived);

        // Swap debt asset received from the deposit to the collateral asset, to repay the flash loan
        params.debtAsset.approve(address(swapper), params.requiredDebt);
        uint256 toAmount = swapper.swap(
            params.debtAsset, params.collateralAsset, params.requiredDebt, collateralLoanAmount, params.providerSwapData
        );

        // Approve morpho to transfer assets received from the swap to repay the flash loan
        params.collateralAsset.approve(address(morpho), collateralLoanAmount);

        // TODO: What to do with surplus received from the swap, if any? Should they be given to the deposit receiver?
        if (toAmount > collateralLoanAmount) {
            SafeERC20.safeTransfer(params.collateralAsset, params.receiver, toAmount - collateralLoanAmount);
        }
    }
}
