// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Internal imports
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

contract AddCollateralInvariants is InvariantTestBase {
    function invariant_addCollateral() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.AddCollateral) {
            return;
        }

        LeverageManagerHandler.AddCollateralActionData memory addCollateralData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.AddCollateralActionData));
        uint256 collateralAfter = leverageManager.getStrategyLendingAdapter(stateBefore.strategy).getCollateral();

        if (addCollateralData.collateral > 0) {
            assertGt(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after adding collateral must be greater than the collateral before adding collateral."
            );
            assertGe(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after adding collateral must be greater than or equal to the collateral before adding more collateral."
            );
        } else {
            assertEq(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after adding collateral must be equal to the collateral before if no collateral was added."
            );
        }
    }
}
