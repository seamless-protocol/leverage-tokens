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

contract WithdrawInvariants is InvariantTestBase {
    function invariant_withdraw() public view {
        LeverageManagerHandler.StrategyStateData memory stateBefore = leverageManagerHandler.getStrategyStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Withdraw) {
            return;
        }

        LeverageManagerHandler.WithdrawActionData memory withdrawData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.WithdrawActionData));
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(withdrawData.strategy);

        _assertCollateralRatioInvariants(stateBefore, withdrawData, stateAfter);
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.StrategyStateData memory stateBefore,
        LeverageManagerHandler.WithdrawActionData memory withdrawData,
        StrategyState memory stateAfter
    ) internal view {
        uint256 totalSupplyAfter = withdrawData.strategy.totalSupply();

        // If zero shares were burned, or zero equity was passed to the withdraw function, strategy collateral ratio should not change
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
                        _getAllowedCollateralRatioSlippage(
                            Math.min(stateBefore.collateral, stateBefore.debt)
                        ),
                        "Invariant Violated: Collateral ratio after withdraw must be equal to the initial collateral ratio, within the allowed slippage."
                    );
                }

                // MockLendingAdapter lendingAdapter =
                //     MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(withdrawData.strategy)));
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
                //     Strings.toString(leverageManager.getStrategyLendingAdapter(withdrawData.strategy).getCollateral()),
                //     " stateAfter.collateralInDebtAsset: ",
                //     Strings.toString(stateAfter.collateralInDebtAsset),
                //     " stateAfter.debt: ",
                //     Strings.toString(stateAfter.debt),
                //     " stateAfter.equityInCollateralAsset: ",
                //     Strings.toString(
                //         leverageManager.getStrategyLendingAdapter(withdrawData.strategy).getEquityInCollateralAsset()
                //     ),
                //     " stateAfter.collateralRatio: ",
                //     Strings.toString(stateAfter.collateralRatio),
                //     " stateAfter.totalSupply: ",
                //     Strings.toString(withdrawData.strategy.totalSupply())
                // );
                // string memory debug3 = string.concat(
                //     " exchangeRate: ",
                //     Strings.toString(lendingAdapter.collateralToDebtAssetExchangeRate()),
                //     " equityInCollateralAsset deposited: ",
                //     Strings.toString(withdrawData.equityInCollateralAsset)
                // );

                // assertGe(
                //     stateAfter.collateralRatio,
                //     stateBefore.collateralRatio,
                //     string.concat(
                //         "Invariant Violated: Collateral ratio after withdraw must be greater than or equal to the initial collateral ratio if there is still debt in the strategy after the withdraw.",
                //         debug,
                //         debug2,
                //         debug3
                //     )
                // );
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
