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

    error InsufficientCollateral();

    error Unauthorized();

    struct DepositParams {
        IStrategy strategy;
        IERC20 collateralAsset;
        IERC20 debtAsset;
        uint256 equityInCollateralAsset;
        uint256 maxSenderSuppliedCollateralAssets;
        uint256 requiredCollateral;
        uint256 requiredDebt;
        uint256 minShares;
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
    ///      swap. This calldata is obtained off-chain by the LiFi API, which requires knowledge of the amount of collateral needed
    ///      from swapping the debt asset to repay the flash loan used to deposit the equity into the strategy.
    /// @param strategy Strategy to preview collateral and debt for
    /// @param equityInCollateralAsset Equity in collateral asset to preview collateral and debt for
    /// @return collateral Collateral required
    /// @return debt Debt required
    function previewCollateralAndDebtRequiredForDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
        public
        view
        returns (uint256 collateral, uint256 debt)
    {
        return leverageManager.getStrategyCollateralAndDebtForEquity(
            strategy, equityInCollateralAsset, IFeeManager.Action.Deposit
        );
    }

    /// @notice Deposit equity into a strategy
    /// @dev The LeverageRouter must be approved to spend `maxCollateralAssets` of the strategy's collateral asset
    /// @param strategy Strategy to deposit equity into
    /// @param equityInCollateralAsset Equity amount in collateral asset to deposit
    /// @param maxSenderSuppliedCollateralAssets The maximum amount of collateral assets to transfer to this contract from the sender to facilitate the deposit of `equityInCollateralAsset` into the strategy
    /// @param minShares Minimum shares to receive from the deposit
    /// @param providerSwapData Swap data to use for the swap using the set provider
    function deposit(
        IStrategy strategy,
        uint256 equityInCollateralAsset,
        uint256 maxSenderSuppliedCollateralAssets,
        uint256 minShares,
        bytes calldata providerSwapData
    ) external {
        if (maxSenderSuppliedCollateralAssets < equityInCollateralAsset) revert InsufficientCollateral();

        ILeverageManager _leverageManager = leverageManager;
        IERC20 collateralAsset = _leverageManager.getStrategyCollateralAsset(strategy);

        collateralAsset.transferFrom(msg.sender, address(this), maxSenderSuppliedCollateralAssets);

        // Get required collateral amount for the equity amount being deposited into the strategy
        (uint256 requiredCollateral, uint256 requiredDebt) =
            previewCollateralAndDebtRequiredForDeposit(strategy, equityInCollateralAsset);

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
                        maxSenderSuppliedCollateralAssets: maxSenderSuppliedCollateralAssets,
                        requiredCollateral: requiredCollateral,
                        requiredDebt: requiredDebt,
                        minShares: minShares,
                        receiver: msg.sender,
                        providerSwapData: providerSwapData
                    })
                )
            );
        } else {
            collateralAsset.approve(address(_leverageManager), requiredCollateral);
            uint256 sharesReceived = _leverageManager.deposit(strategy, equityInCollateralAsset, minShares);

            SafeERC20.safeTransfer(strategy, msg.sender, sharesReceived);
            SafeERC20.safeTransfer(debtAsset, msg.sender, requiredDebt);

            uint256 collateralAssetSurplus = maxSenderSuppliedCollateralAssets - equityInCollateralAsset;
            if (collateralAssetSurplus > 0) {
                SafeERC20.safeTransfer(collateralAsset, msg.sender, collateralAssetSurplus);
            }
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

        // Deposit equity into strategy and give receiver the minted shares and debt assets
        params.collateralAsset.approve(address(_leverageManager), params.requiredCollateral);
        uint256 sharesReceived =
            _leverageManager.deposit(params.strategy, params.equityInCollateralAsset, params.minShares);

        // Swap debt asset received from the deposit to the collateral asset, to repay the flash loan
        params.debtAsset.approve(address(swapper), params.requiredDebt);
        uint256 toAmount = swapper.swap(
            params.debtAsset, params.collateralAsset, params.requiredDebt, collateralLoanAmount, params.providerSwapData
        );

        // The remaining sender supplied collateral is the amount of collateral that was not used to deposit the equity into the strategy,
        // which is the portion that is equal to the deposited equity amount. The rest of the collateral used for the deposit was from the flash loan
        uint256 remainingSenderSuppliedCollateral =
            params.maxSenderSuppliedCollateralAssets - params.equityInCollateralAsset;
        uint256 collateralAssetSurplus = toAmount + remainingSenderSuppliedCollateral - collateralLoanAmount;

        // Return any surplus collateral asset not used to repay the flash loan to the deposit receiver
        if (collateralAssetSurplus > 0) {
            SafeERC20.safeTransfer(params.collateralAsset, params.receiver, collateralAssetSurplus);
        }

        // Transfer shares received from the deposit to the receiver
        SafeERC20.safeTransfer(params.strategy, params.receiver, sharesReceived);

        // Approve morpho to transfer assets received from the swap to repay the flash loan
        params.collateralAsset.approve(address(morpho), collateralLoanAmount);
    }
}
