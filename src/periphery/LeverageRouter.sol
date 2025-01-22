// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {OneInchSwapDescription} from "src/interfaces/IOneInchAggregationRouterV6.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract LeverageRouter {
    ILeverageManager public immutable leverageManager;

    IMorpho public immutable morpho;

    ISwapper public immutable swapper;

    ISwapper.Provider public provider;

    error Unauthorized();

    struct DepositParams {
        IStrategy strategy;
        address collateralAsset;
        address debtAsset;
        uint256 equityInCollateralAsset;
        uint256 requiredCollateral;
        uint256 requiredDebt;
        address receiver;
        bytes providerSwapData;
    }

    constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapper _swapper, ISwapper.Provider _provider) {
        leverageManager = _leverageManager;
        morpho = _morpho;
        swapper = _swapper;
        provider = _provider;
    }

    /// @notice Preview total collateral and debt required for a deposit of equity into a strategy
    /// @dev This function is useful for generating swap aggregator data required for a deposit.
    ///      For example, if the LeverageRouter is using 1inch for swaps, the caller needs to pass in the 1inch executor,
    ///      description, and swap tx data, obtained off-chain by the 1inch API. This requires knowledge of the amount of
    ///      debt to swap to the collateral asset for repaying the flash loan used to deposit the equity into the strategy.
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

    function setProvider(ISwapper.Provider _provider) external {
        // TODO: Only authed role allowed to set provider
        // TODO: Does this contract need to be upgradeable? Doesn't hold any funds, but maybe for any fixes / improvements?
        provider = _provider;
    }

    /// @notice Deposit equity into a strategy
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

        // Flash loan any additional required collateral from morpho
        if (requiredCollateral > equityInCollateralAsset) {
            morpho.flashLoan(
                address(collateralAsset),
                requiredCollateral - equityInCollateralAsset,
                abi.encode(
                    DepositParams({
                        strategy: strategy,
                        collateralAsset: address(collateralAsset),
                        debtAsset: address(_leverageManager.getStrategyDebtAsset(strategy)),
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
            IERC20(address(strategy)).transfer(msg.sender, sharesReceived);
        }
    }

    /// @notice Callback function for morpho flash loan
    /// @dev This function is called by morpho when a flash loan is taken. It is expected to repay the flash loan
    /// @param loanAmount Amount of asset flash loaned
    /// @param data Encoded data passed to `morpho.flashLoan`. In this case, it contains `DepositParams`
    function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert Unauthorized();

        DepositParams memory params = abi.decode(data, (DepositParams));
        ILeverageManager _leverageManager = leverageManager;

        // Convert equity to expected strategy shares
        uint256 minShares = _leverageManager.convertEquityToShares(params.strategy, params.equityInCollateralAsset);

        // Deposit equity into strategy and give receiver the minted shares
        IERC20(params.collateralAsset).approve(address(_leverageManager), params.requiredCollateral);
        uint256 sharesReceived = _leverageManager.deposit(params.strategy, params.equityInCollateralAsset, minShares);
        IERC20(address(params.strategy)).transfer(params.receiver, sharesReceived);

        // Swap debt asset received from the deposit to the collateral asset, to repay the flash loan
        IERC20(params.debtAsset).approve(address(swapper), params.requiredDebt);
        uint256 toAmount =
            swapper.swap(provider, IERC20(params.debtAsset), params.requiredDebt, loanAmount, params.providerSwapData);

        // Approve morpho to transfer assets received from the swap to repay the flash loan
        IERC20(params.collateralAsset).approve(address(morpho), loanAmount);

        // TODO: What to do with surplus received from the swap, if any? Should they be given to the deposit receiver?
        if (toAmount > loanAmount) {
            IERC20(params.collateralAsset).transfer(params.receiver, toAmount - loanAmount);
        }
    }
}
