// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";

contract WithdrawInvariants is InvariantTestBase {
    function invariant_withdraw() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Withdraw) {
            return;
        }

        LeverageManagerHandler.WithdrawActionData memory withdrawData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.WithdrawActionData));
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(withdrawData.strategy);

        _assertPreviewInvariants(stateBefore, withdrawData);
        _assertCollateralRatioInvariants(stateBefore, withdrawData, stateAfter);
        _assertWithdrawBalanceInvariants(stateBefore, withdrawData, stateAfter);
    }

    function _assertPreviewInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData
    ) internal view {
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(withdrawData.strategy);

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
            stateBefore.totalSupply - withdrawData.strategy.totalSupply(),
            "Invariant Violated: Change in shares from withdraw must match the withdraw preview."
        );
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData,
        StrategyState memory stateAfter
    ) internal view {
        uint256 totalSupplyAfter = withdrawData.strategy.totalSupply();
        // If zero shares were burnt, or zero equity was passed to the withdraw function, strategy state should not change
        if (stateBefore.totalSupply == totalSupplyAfter || withdrawData.equityInCollateralAsset == 0) {
            assertEq(
                stateBefore.collateralRatio,
                stateAfter.collateralRatio,
                "Invariant Violated: Collateral ratio should not change if zero shares were burnt or zero equity was passed to the withdraw function."
            );
        } else {
            if (stateAfter.debt != 0) {
                // assertApproxEqRel scales the difference by 1e18, so we can't check this if the difference is too high
                uint256 collateralRatioDiff = stdMath.delta(stateAfter.collateralRatio, stateBefore.collateralRatio);
                if (collateralRatioDiff == 0 || type(uint256).max / 1e18 >= collateralRatioDiff) {
                    assertApproxEqRel(
                        stateAfter.collateralRatio,
                        stateBefore.collateralRatio,
                        _getAllowedCollateralRatioSlippage(Math.min(stateBefore.collateral, stateBefore.debt)),
                        "Invariant Violated: Collateral ratio after withdraw must be equal to the initial collateral ratio, within the allowed slippage."
                    );
                }
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after withdrawing all debt should be max uint256."
                );
            }
        }
    }

    function _assertWithdrawBalanceInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData,
        StrategyState memory stateAfter
    ) internal view {
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(withdrawData.strategy);
        uint256 totalSupplyAfter = withdrawData.strategy.totalSupply();
        uint256 collateralAfter = lendingAdapter.getCollateral();

        if (stateBefore.totalSupply != totalSupplyAfter) {
            assertLt(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after withdraw should be less than the initial collateral if shares were burned."
            );
            if (stateBefore.debt != 0) {
                assertLe(
                    stateAfter.debt,
                    stateBefore.debt,
                    "Invariant Violated: Debt after withdraw should be less than or equal to the initial debt if shares were burned."
                );
            }
        } else {
            assertEq(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after withdraw should not change if shares were not burned."
            );
            assertEq(
                stateAfter.debt,
                stateBefore.debt,
                "Invariant Violated: Debt after withdraw should not change if shares were not burned."
            );
        }

        if (stateBefore.totalSupply > 0 && totalSupplyAfter == 0) {
            assertEq(
                stateAfter.collateralInDebtAsset,
                0,
                "Invariant Violated: Collateral in debt asset after a withdraw that burned all shares should be 0."
            );
            assertEq(stateAfter.debt, 0, "Invariant Violated: Debt after burned all shares should be 0.");
        }
    }
}
