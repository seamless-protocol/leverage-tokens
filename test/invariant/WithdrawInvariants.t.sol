// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

contract WithdrawInvariants is InvariantTestBase {
    function invariant_withdraw() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Withdraw) {
            return;
        }

        LeverageManagerHandler.WithdrawActionData memory withdrawData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.WithdrawActionData));
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(stateBefore.strategy);
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(stateBefore.strategy);

        _assertPreviewInvariants(lendingAdapter, stateBefore, withdrawData);
        _assertCollateralRatioInvariants(stateBefore, withdrawData, stateAfter);
    }

    function _assertPreviewInvariants(
        ILendingAdapter lendingAdapter,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData
    ) internal view {
        assertEq(
            withdrawData.preview.collateral,
            stateBefore.collateral - lendingAdapter.getCollateral(),
            "Invariant Violated: Change in collateral from withdraw must match the withdraw preview."
        );
        assertEq(
            withdrawData.preview.debt,
            stateBefore.debt - lendingAdapter.getDebt(),
            "Invariant Violated: Change in debt from withdraw must match the withdraw preview."
        );
        assertEq(
            withdrawData.preview.shares,
            stateBefore.totalSupply - stateBefore.strategy.totalSupply(),
            "Invariant Violated: Change in shares from withdraw must match the withdraw preview."
        );
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData,
        StrategyState memory stateAfter
    ) internal view {
        // If zero shares were burnt, or zero equity was passed to the withdraw function, strategy state should not change
        if (stateBefore.totalSupply == stateBefore.strategy.totalSupply() || withdrawData.equityInCollateralAsset == 0)
        {
            assertEq(
                stateBefore.collateral,
                leverageManager.getStrategyLendingAdapter(stateBefore.strategy).getCollateral(),
                "Invariant Violated: Collateral should not change if zero shares were burnt or zero equity was passed to the withdraw function."
            );
            assertEq(
                stateBefore.debt,
                stateAfter.debt,
                "Invariant Violated: Debt should not change if zero shares were burnt or zero equity was passed to the withdraw function."
            );
            assertEq(
                stateBefore.collateralRatio,
                stateAfter.collateralRatio,
                "Invariant Violated: Collateral ratio should not change if zero shares were burnt or zero equity was passed to the withdraw function."
            );
        } else {
            assertGe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after withdraw must be greater than or equal to the initial collateral ratio."
            );

            if (stateAfter.debt != 0) {
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    stateBefore.collateralRatio,
                    _getAllowedCollateralRatioSlippage(stateBefore.debt),
                    "Invariant Violated: Collateral ratio after withdraw must be equal to the initial collateral ratio, within the allowed collateral ratio slippage."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after withdrawing all debt should be max uint256."
                );
            }
        }
    }
}
