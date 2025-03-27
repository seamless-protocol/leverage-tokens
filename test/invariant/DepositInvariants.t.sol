// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";

contract DepositInvariants is InvariantTestBase {
    function invariant_deposit() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Deposit) {
            return;
        }

        LeverageManagerHandler.DepositActionData memory depositData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.DepositActionData));
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(depositData.strategy);

        // Check if ILendingAdapter.convertCollateralToDebtAsset(strategy collateral) will overflow. If it does, we cannot
        // check collateral ratio invariants without running into overflows, since calculating collateral ratio requires
        // normalizing collateral and debt.
        // Note: Deposits can still occur if ILendingAdapter.convertCollateralToDebtAsset(strategy collateral) overflows,
        //       because the logic in LeverageManager does not convert collateral to debt during a deposit.
        if (
            type(uint256).max / MockLendingAdapter(address(lendingAdapter)).collateralToDebtAssetExchangeRate()
                >= lendingAdapter.getCollateral()
        ) {
            StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(depositData.strategy);
            _assertCollateralRatioInvariants(depositData, stateBefore, stateAfter);
        }

        _assertShareValueInvariants(depositData, stateBefore);
    }

    function _assertShareValueInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore
    ) internal view {
        uint256 sharesMinted = depositData.strategy.totalSupply() - stateBefore.totalSupply;
        uint256 sharesMintedValue = leverageManagerHandler.convertToAssets(depositData.strategy, sharesMinted);
        uint256 equityDelta = leverageManager.getStrategyLendingAdapter(depositData.strategy).getEquityInCollateralAsset(
        ) - stateBefore.equityInCollateralAsset;
        assertLe(
            sharesMintedValue,
            equityDelta,
            "Invariant Violated: The value of the minted shares from a deposit must be less than or equal to the equity added to the leverage token."
        );

        assertGe(
            leverageManagerHandler.convertToAssets(depositData.strategy, stateBefore.totalSupply + 1), // +1 to accommodate for offset
            stateBefore.equityInCollateralAsset,
            "Invariant Violated: Existing total share value must be greater than or equal to the value before the deposit."
        );
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        _assertCollateralRatioNonEmptyStrategy(stateBefore, stateAfter);
        _assertCollateralRatioEmptyStrategy(depositData, stateBefore, stateAfter);
        _assertCollateralRatioZeroEquityDeposit(depositData, stateBefore, stateAfter);
    }

    function _assertCollateralRatioNonEmptyStrategy(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal pure {
        if (stateBefore.totalSupply == 0 || stateBefore.debt == 0) {
            return;
        }

        // MockLendingAdapter lendingAdapter =
        //     MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(depositData.strategy)));
        // string memory debug = string.concat(
        //     " stateBefore.totalSupply: ",
        //     Strings.toString(stateBefore.totalSupply),
        //     " stateBefore.collateral: ",
        //     Strings.toString(stateBefore.collateral),
        //     " stateBefore.collateralInDebtAsset: ",
        //     Strings.toString(stateBefore.collateralInDebtAsset),
        //     " stateBefore.debt: ",
        //     Strings.toString(stateBefore.debt),
        //     " stateBefore.equityInCollateralAsset: ",
        //     Strings.toString(stateBefore.equityInCollateralAsset),
        //     " stateBefore.collateralRatio: ",
        //     Strings.toString(stateBefore.collateralRatio)
        // );
        // string memory debug2 = string.concat(
        //     " stateAfter.collateral: ",
        //     Strings.toString(leverageManager.getStrategyLendingAdapter(depositData.strategy).getCollateral()),
        //     " stateAfter.collateralInDebtAsset: ",
        //     Strings.toString(stateAfter.collateralInDebtAsset),
        //     " stateAfter.debt: ",
        //     Strings.toString(stateAfter.debt),
        //     " stateAfter.equityInCollateralAsset: ",
        //     Strings.toString(
        //         leverageManager.getStrategyLendingAdapter(depositData.strategy).getEquityInCollateralAsset()
        //     ),
        //     " stateAfter.collateralRatio: ",
        //     Strings.toString(stateAfter.collateralRatio),
        //     " stateAfter.totalSupply: ",
        //     Strings.toString(depositData.strategy.totalSupply())
        // );
        // string memory debug3 = string.concat(
        //     " exchangeRate: ",
        //     Strings.toString(lendingAdapter.collateralToDebtAssetExchangeRate()),
        //     " equityInCollateralAsset deposited: ",
        //     Strings.toString(depositData.equityInCollateralAsset)
        // );

        // assertGe(
        //     stateAfter.collateralRatio,
        //     stateBefore.collateralRatio,
        //     string.concat(
        //         "Invariant Violated: Collateral ratio after deposit into a non-empty strategy must be greater than or equal to the initial collateral ratio.",
        //         debug,
        //         debug2,
        //         debug3
        //     )
        // );

        // assertApproxEqRel scales the difference by 1e18, so we can't check this if the difference is too high
        uint256 collateralRatioDiff = stdMath.delta(stateAfter.collateralRatio, stateBefore.collateralRatio);
        if (collateralRatioDiff == 0 || type(uint256).max / 1e18 >= collateralRatioDiff) {
            assertApproxEqRel(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                _getAllowedCollateralRatioSlippage(Math.min(stateBefore.collateral, stateBefore.debt)),
                "Invariant Violated: Collateral ratio after deposit into a non-empty strategy must be equal to the initial collateral ratio, within the allowed slippage."
            );
        }
    }

    function _assertCollateralRatioEmptyStrategy(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        if (stateBefore.totalSupply == 0 && stateBefore.collateralInDebtAsset == 0 && stateBefore.debt == 0) {
            uint256 targetCollateralRatio = leverageManager.getStrategyTargetCollateralRatio(depositData.strategy);

            if (stateAfter.debt > 0) {
                // For an empty strategy, the debt amount is calculated as the difference between:
                // 1. The required collateral (determined using target ratio and the amount of equity to deposit)
                // 2. The equity being deposited
                // Thus, the precision of the resulting collateral ratio is higher as the amount of equity increases, and
                // lower as the amount of equity decreases.
                // For example:
                //     collateral and debt are 1:1
                //     targetCollateralRatio = 5e8
                //     equityDeposited = 583
                //     collateralRequiredForDeposit = 583 * 5e8 / (5e8 - 1e8) = 728.75 (729 rounded up)
                //     debtRequiredForDeposit = 729 - 583 = 146
                //     collateralRatioAfterDeposit = 729 / 146 = 4.9931506849 (not the target 5e8)
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    targetCollateralRatio,
                    // The allowed slippage is based on the equity being deposited, as the calculation of the collateral
                    // and debt required for the this case uses equityInCollateralAsset, and the collateral ratio is calculated
                    // using the equityInCollateralAsset converted to debt
                    _getAllowedCollateralRatioSlippage(
                        Math.min(depositData.equityInCollateralAsset, depositData.equityInDebtAsset)
                    ),
                    "Invariant Violated: Collateral ratio after deposit into an empty strategy must be equal to the target collateral ratio, within the allowed slippage."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after a deposit into an empty strategy that results in no debt should be type(uint256).max."
                );
            }
        }
    }

    function _assertCollateralRatioZeroEquityDeposit(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal pure {
        if (depositData.equityInCollateralAsset == 0) {
            assertEq(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after a deposit of zero equity should be equal to the initial collateral ratio."
            );
        }
    }
}
