// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

        _assertPreviewInvariants(stateBefore, depositData);
        _assertBalanceInvariants(stateBefore, depositData);

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
    }

    function _assertBalanceInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.DepositActionData memory depositData
    ) internal view {
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(depositData.strategy);
        uint256 totalSupplyAfter = depositData.strategy.totalSupply();
        uint256 collateralAfter = lendingAdapter.getCollateral();
        uint256 equityAfter = lendingAdapter.getEquityInCollateralAsset();

        if (totalSupplyAfter > stateBefore.totalSupply) {
            assertGt(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after deposit should be greater than the initial collateral if shares were minted."
            );
            assertGt(
                equityAfter,
                stateBefore.equityInCollateralAsset,
                "Invariant Violated: Equity after deposit should be greater than the initial equity if shares were minted."
            );
        } else {
            assertGe(
                collateralAfter,
                stateBefore.collateral,
                "Invariant Violated: Collateral after deposit should be greater than or equal to the initial collateral if shares were not minted."
            );
            assertGe(
                equityAfter,
                stateBefore.equityInCollateralAsset,
                "Invariant Violated: Equity after deposit should be greater than or equal to the initial equity if shares were not minted."
            );
        }
    }

    function _assertPreviewInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.DepositActionData memory depositData
    ) internal view {
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(depositData.strategy);

        assertEq(
            lendingAdapter.getCollateral() - stateBefore.collateral,
            depositData.preview.collateral,
            "Invariant Violated: Change in collateral from deposit must match the deposit preview."
        );
        assertEq(
            lendingAdapter.getDebt() - stateBefore.debt,
            depositData.preview.debt,
            "Invariant Violated: Change in debt from deposit must match the deposit preview."
        );
        assertEq(
            depositData.strategy.totalSupply() - stateBefore.totalSupply,
            depositData.preview.shares,
            "Invariant Violated: Change in shares from deposit must match the deposit preview."
        );
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        _assertEmptyStrategyDepositCollateralRatioInvariants(depositData, stateBefore, stateAfter);
        _assertZeroSupplyNonZeroCollateralAndDebtDepositCollateralRatioInvariants(depositData, stateBefore, stateAfter);
        _assertZeroDebtDepositCollateralRatioInvariants(depositData, stateBefore, stateAfter);
        _assertNonEmptyStrategyDepositCollateralRatioInvariants(stateBefore, stateAfter);
        _assertZeroEquityDepositCollateralRatioInvariants(depositData, stateBefore, stateAfter);
    }

    function _assertEmptyStrategyDepositCollateralRatioInvariants(
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

    function _assertZeroSupplyNonZeroCollateralAndDebtDepositCollateralRatioInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        uint256 debtAdded = stateAfter.debt - stateBefore.debt;
        if (stateBefore.totalSupply == 0 && stateBefore.collateralInDebtAsset > 0 && stateBefore.debt > 0) {
            if (debtAdded > 0) {
                _assertDepositCollateralRatioEqualsTarget(
                    depositData,
                    stateBefore,
                    stateAfter,
                    "Invariant Violated: Collateral ratio for a deposit into a strategy with zero shares, collateral > 0, and debt > 0 must be equal to the target collateral ratio, within the allowed slippage."
                );
            } else {
                assertGe(
                    stateAfter.collateralRatio,
                    stateBefore.collateralRatio,
                    "Invariant Violated: Collateral ratio for a deposit into a strategy with zero shares, collateral > 0, and debt > 0 must be greater than or equal to the initial collateral ratio if no debt was added."
                );
            }
        }
    }

    function _assertZeroDebtDepositCollateralRatioInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal view {
        if (stateBefore.debt == 0) {
            uint256 debtAdded = stateAfter.debt - stateBefore.debt;
            if (debtAdded > 0) {
                _assertDepositCollateralRatioEqualsTarget(
                    depositData,
                    stateBefore,
                    stateAfter,
                    "Invariant Violated: Collateral ratio for a deposit into a strategy with zero debt must be equal to the target collateral ratio, within the allowed slippage."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after a deposit with zero debt added must be type(uint256).max."
                );
            }
        }
    }

    function _assertNonEmptyStrategyDepositCollateralRatioInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter
    ) internal pure {
        if (stateBefore.totalSupply == 0 || stateBefore.debt == 0) {
            return;
        }

        if (stateBefore.collateralInDebtAsset > 0) {
            assertApproxEqRel(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                _getAllowedCollateralRatioSlippage(Math.min(stateBefore.collateral, stateBefore.debt)),
                "Invariant Violated: Collateral ratio after deposit must be equal to the initial collateral ratio, within the allowed collateral ratio slippage."
            );
        } else {
            assertTrue(
                stateAfter.collateralRatio >= stateBefore.collateralRatio && stateBefore.collateralRatio == 0,
                "Invariant Violated: Collateral ratio after deposit must be greater than or equal to the initial collateral ratio when collateral in debt asset was 0 (and thus the initial collateral ratio was 0)."
            );
        }
    }

    function _assertZeroEquityDepositCollateralRatioInvariants(
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

    function _assertDepositCollateralRatioEqualsTarget(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        StrategyState memory stateAfter,
        string memory errorMessage
    ) internal view {
        uint256 collateralAddedInDebtAsset = stateAfter.collateralInDebtAsset - stateBefore.collateralInDebtAsset;
        uint256 debtAddedInDebtAsset = stateAfter.debt - stateBefore.debt;

        uint256 depositCollateralRatio = collateralAddedInDebtAsset * BASE_RATIO / debtAddedInDebtAsset;
        assertApproxEqRel(
            depositCollateralRatio,
            leverageManager.getStrategyTargetCollateralRatio(depositData.strategy),
            // The allowed slippage is based on the equity being deposited, as the calculation of the collateral
            // and debt required for this case uses equityInCollateralAsset, and the collateral ratio is calculated
            // using the equityInCollateralAsset converted to debt
            _getAllowedCollateralRatioSlippage(
                Math.min(depositData.equityInCollateralAsset, depositData.equityInDebtAsset)
            ),
            errorMessage
        );
    }
}
