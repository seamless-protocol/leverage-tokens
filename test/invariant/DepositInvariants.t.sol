// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

contract DepositInvariants is InvariantTestBase {
    function invariant_deposit() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Deposit) {
            return;
        }

        LeverageManagerHandler.DepositActionData memory depositData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.DepositActionData));
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(stateBefore.strategy);

        // Empty strategy
        if (stateBefore.totalSupply == 0 && stateBefore.collateralInDebtAsset == 0 && stateBefore.debt == 0) {
            if (depositData.equityInCollateralAsset != 0) {
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
                    leverageManager.getStrategyTargetCollateralRatio(stateBefore.strategy),
                    _getAllowedCollateralRatioSlippage(depositData.equityInCollateralAsset),
                    "Invariant Violated: Collateral ratio after deposit must be equal to the target collateral ratio, within the allowed collateral ratio slippage, if the strategy was initially empty."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after deposit must be type(uint256).max if no equity was deposited into an empty strategy."
                );
            }
        }
        // Strategy with 0 shares but collateral > 0 and debt > 0
        else if (stateBefore.totalSupply == 0 && stateBefore.collateralInDebtAsset != 0 && stateBefore.debt != 0) {
            // It's possible that the strategy has no shares but has non-zero collateral and debt due to actors adding
            // collateral to the underlying position held by the strategy (directly, not through LeverageManager.deposit)
            // before any shares are minted.
            // There can be debt because minShares is set to 0 in `LeverageManagerHandler.deposit`, so a depositor can add
            // collateral and debt without receiving any shares.
            assertLe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after deposit must be less than or equal to the initial collateral ratio if the strategy has no shares but has non-zero collateral and debt."
            );
        }
        // Strategy with 0 debt and non-zero collateral
        else if (stateBefore.collateralInDebtAsset != 0 && stateBefore.debt == 0) {
            uint256 collateralAddedInDebtAsset = stateAfter.collateralInDebtAsset - stateBefore.collateralInDebtAsset;
            uint256 debtAddedInDebtAsset = stateAfter.debt - stateBefore.debt;

            if (debtAddedInDebtAsset != 0) {
                uint256 depositCollateralRatio = collateralAddedInDebtAsset * BASE_RATIO / debtAddedInDebtAsset;

                assertApproxEqRel(
                    depositCollateralRatio,
                    leverageManager.getStrategyTargetCollateralRatio(stateBefore.strategy),
                    _getAllowedCollateralRatioSlippage(depositData.equityInCollateralAsset),
                    "Invariant Violated: Collateral ratio for a deposit into a strategy with non-zero collateral and zero debt must be equal to the target collateral ratio, within the allowed collateral ratio slippage."
                );
            }
        } else {
            assertGe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after deposit must be greater than or equal to the initial collateral ratio."
            );
            assertApproxEqRel(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                _getAllowedCollateralRatioSlippage(stateBefore.debt),
                "Invariant Violated: Collateral ratio after deposit must be equal to the initial collateral ratio, within the allowed collateral ratio slippage."
            );
        }
    }
}
