// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";

contract DepositInvariants is InvariantTestBase {
    function invariant_deposit() public view {
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore =
            leverageManagerHandler.getLeverageTokenStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Deposit) {
            return;
        }

        LeverageManagerHandler.DepositActionData memory depositData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.DepositActionData));
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(depositData.leverageToken);

        // Check if ILendingAdapter.convertCollateralToDebtAsset(leverageToken collateral) will overflow. If it does, we cannot
        // check collateral ratio invariants without running into overflows, since calculating collateral ratio requires
        // normalizing collateral and debt.
        // Note: Deposits can still occur if ILendingAdapter.convertCollateralToDebtAsset(leverageToken collateral) overflows,
        //       because the logic in LeverageManager does not convert collateral to debt during a deposit.
        if (
            type(uint256).max / MockLendingAdapter(address(lendingAdapter)).collateralToDebtAssetExchangeRate()
                >= lendingAdapter.getCollateral()
        ) {
            LeverageTokenState memory stateAfter = leverageManager.getLeverageTokenState(depositData.leverageToken);
            _assertCollateralRatioInvariants(depositData, stateBefore, stateAfter);
        }

        _assertShareValueInvariants(depositData, stateBefore);
    }

    function _assertShareValueInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore
    ) internal view {
        uint256 sharesMinted = depositData.leverageToken.totalSupply() - stateBefore.totalSupply;
        uint256 sharesMintedValue = leverageManagerHandler.convertToAssets(depositData.leverageToken, sharesMinted);
        uint256 equityDelta = leverageManager.getLeverageTokenLendingAdapter(depositData.leverageToken)
            .getEquityInCollateralAsset() - stateBefore.equityInCollateralAsset;
        assertLe(
            sharesMintedValue,
            equityDelta,
            "Invariant Violated: The value of the minted shares from a deposit must be less than or equal to the equity added to the leverage token."
        );

        assertGe(
            leverageManagerHandler.convertToAssets(depositData.leverageToken, stateBefore.totalSupply + 1), // +1 to accommodate for offset
            stateBefore.equityInCollateralAsset,
            "Invariant Violated: Existing total share value must be greater than or equal to the value before the deposit."
        );
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter
    ) internal view {
        _assertCollateralRatioNonEmptyLeverageToken(stateBefore, stateAfter);
        _assertCollateralRatioEmptyLeverageToken(depositData, stateBefore, stateAfter);
        _assertCollateralRatioZeroEquityDeposit(depositData, stateBefore, stateAfter);
    }

    function _assertCollateralRatioNonEmptyLeverageToken(
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter
    ) internal pure {
        if (stateBefore.totalSupply == 0 || stateBefore.debt == 0) {
            return;
        }

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

    function _assertCollateralRatioEmptyLeverageToken(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter
    ) internal view {
        if (stateBefore.totalSupply == 0 && stateBefore.collateralInDebtAsset == 0 && stateBefore.debt == 0) {
            uint256 targetCollateralRatio =
                leverageManager.getLeverageTokenTargetCollateralRatio(depositData.leverageToken);

            if (stateAfter.debt > 0) {
                // For an empty leverage token, the debt amount is calculated as the difference between:
                // 1. The required collateral (determined using target ratio and the amount of equity to deposit)
                // 2. The equity being deposited
                // Thus, the precision of the resulting collateral ratio is higher as the amount of equity increases, and
                // lower as the amount of equity decreases.
                // For example:
                //     collateral and debt are 1:1
                //     targetCollateralRatio = 5e18
                //     equityDeposited = 583
                //     collateralRequiredForDeposit = 583 * 5e18 / (5e18 - 1e18) = 728.75 (729 rounded up)
                //     debtRequiredForDeposit = 729 - 583 = 146
                //     collateralRatioAfterDeposit = 729 / 146 = 4.9931506849 (not the target 5e18)
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    targetCollateralRatio,
                    // The allowed slippage is based on the equity being deposited, as the calculation of the collateral
                    // and debt required for the this case uses equityInCollateralAsset, and the collateral ratio is calculated
                    // using the equityInCollateralAsset converted to debt
                    _getAllowedCollateralRatioSlippage(
                        Math.min(depositData.equityInCollateralAsset, depositData.equityInDebtAsset)
                    ),
                    "Invariant Violated: Collateral ratio after deposit into an empty LeverageToken must be equal to the target collateral ratio, within the allowed slippage."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after a deposit into an empty LeverageToken that results in no debt should be type(uint256).max."
                );
            }
        }
    }

    function _assertCollateralRatioZeroEquityDeposit(
        LeverageManagerHandler.DepositActionData memory depositData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter
    ) internal pure {
        if (depositData.equityInCollateralAsset == 0) {
            assertEq(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio of a LeverageToken after a deposit of zero equity should be equal to the initial collateral ratio."
            );
        }
    }
}
