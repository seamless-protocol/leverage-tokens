// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

// Mint Invariants:
// - Collateral ratio must equal the collateral ratio before the mint (within some allowed precision loss margin)
// - Shares minted to the user must be equal to the amount of equity added to the LT, minus the token action fee and treasury fee
// - Shares before the mint must be worth greater than or equal to the value before the mint (share price >= before)
contract MintInvariants is InvariantTestBase {
    function invariant_mint() public view {
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore =
            leverageManagerHandler.getLeverageTokenStateBefore();
        if (stateBefore.actionType != LeverageManagerHandler.ActionType.Mint) {
            return;
        }

        LeverageManagerHandler.MintActionData memory mintData =
            abi.decode(stateBefore.actionData, (LeverageManagerHandler.MintActionData));
        IRebalanceAdapterBase rebalanceAdapter =
            leverageManager.getLeverageTokenRebalanceAdapter(mintData.leverageToken);
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(mintData.leverageToken)));

        (,, address oracle,,) = lendingAdapter.marketParams();

        // Check if lendingAdapter.convertCollateralToDebtAsset(total collateral) will overflow. If it does, we cannot
        // check collateral ratio invariants without running into overflows, since calculating collateral ratio requires
        // normalizing collateral and debt.
        // Note: Mints can still occur if ILendingAdapter.convertCollateralToDebtAsset(leverageToken collateral) overflows,
        //       because the logic in LeverageManager does not convert collateral to debt during a mint.
        if (type(uint256).max / IOracle(oracle).price() >= lendingAdapter.getCollateral()) {
            LeverageTokenState memory stateAfter = leverageManager.getLeverageTokenState(mintData.leverageToken);
            _assertCollateralRatioInvariants(mintData, stateBefore, stateAfter, rebalanceAdapter);
        }
    }

    function _assertCollateralRatioInvariants(
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        IRebalanceAdapterBase rebalanceAdapter
    ) internal view {
        if (
            (stateBefore.totalSupply == 0 || stateBefore.debt == 0) && stateBefore.collateral == 0
                && mintData.equityInCollateralAsset != 0
        ) {
            uint256 initialCollateralRatio =
                rebalanceAdapter.getLeverageTokenInitialCollateralRatio(mintData.leverageToken);
            // assertApproxEqRel scales the difference by 1e18, so we can't check assertApproxEqRel if the difference is too high
            uint256 collateralRatioDiff = stdMath.delta(stateAfter.collateralRatio, initialCollateralRatio);
            if (collateralRatioDiff == 0 || type(uint256).max / 1e18 >= collateralRatioDiff) {
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    initialCollateralRatio,
                    _getAllowedCollateralRatioSlippage(mintData.equityInDebtAsset),
                    string.concat(
                        "Invariant Violated: Collateral ratio after mint into an empty LT with no collateral must be equal to the initial collateral ratio, within the allowed slippage.",
                        _getStateBeforeDebugString(stateBefore),
                        _getStateAfterDebugString(stateAfter),
                        _getMintDataDebugString(mintData)
                    )
                );
            }
        }

        if (stateBefore.totalSupply != 0 && stateBefore.debt != 0) {
            // assertApproxEqRel scales the difference by 1e18, so we can't check assertApproxEqRel if the difference is too high
            uint256 collateralRatioDiff = stdMath.delta(stateAfter.collateralRatio, stateBefore.collateralRatio);
            if (collateralRatioDiff == 0 || type(uint256).max / 1e18 >= collateralRatioDiff) {
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    stateBefore.collateralRatio,
                    _getAllowedCollateralRatioSlippage(Math.min(stateBefore.collateral, stateBefore.debt)),
                    string.concat(
                        "Invariant Violated: Collateral ratio after mint into a non-empty strategy must be equal to the initial collateral ratio, within the allowed slippage.",
                        _getStateBeforeDebugString(stateBefore),
                        _getStateAfterDebugString(stateAfter),
                        _getMintDataDebugString(mintData)
                    )
                );
            }
        }
    }
}
