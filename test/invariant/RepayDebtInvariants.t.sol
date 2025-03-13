// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Internal imports
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

contract RepayDebtInvariants is InvariantTestBase {
    function invariant_repayDebt() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.RepayDebt) {
            return;
        }

        LeverageManagerHandler.RepayDebtActionData memory repayDebtData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.RepayDebtActionData));
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(stateBefore.strategy);

        if (repayDebtData.debt > 0) {
            assertLt(
                stateAfter.debt,
                stateBefore.debt,
                "Invariant Violated: Debt after repaying debt must be less than the debt before repaying debt."
            );

            // Due to rounding error depending on the amounts of collateral and debt, it's possible that the ratios are equal after repaying debt.
            assertGe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after repaying debt must be greater than or equal to the collateral ratio before repaying debt."
            );
        } else {
            assertEq(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after repaying debt must be equal to the collateral ratio before repaying debt if no debt was removed."
            );
        }
    }
}
