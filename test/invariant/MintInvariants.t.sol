// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IRebalanceAdapterBase} from "src/interfaces/IRebalanceAdapterBase.sol";
import {ExternalAction, LeverageTokenState} from "src/types/DataTypes.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {InvariantTestBase} from "test/invariant/InvariantTestBase.t.sol";

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

            _assertSharesInvariants(lendingAdapter, mintData, stateBefore, stateAfter);
        }
    }

    function _assertSharesInvariants(
        ILendingAdapter lendingAdapter,
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter
    ) internal view {
        uint256 totalSupplyAfter = mintData.leverageToken.totalSupply();
        uint256 sharesMinted = totalSupplyAfter - stateBefore.totalSupply;

        if (stateBefore.totalSupply != 0) {
            // When the total supply before is 0, this invariant fails as zero shares are always worthless
            assertGe(
                _convertToAssets(stateBefore.leverageToken, stateBefore.totalSupply, Math.Rounding.Ceil),
                stateBefore.equityInCollateralAsset,
                _getMintInvariantDescriptionString(
                    "The value of the total supply of shares before the mint must be greater than or equal to their value before the mint.",
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );

            uint256 mintedSharesValue = _convertToAssets(mintData.leverageToken, sharesMinted, Math.Rounding.Floor);
            uint256 deltaEquityInCollateralAsset =
                lendingAdapter.getEquityInCollateralAsset() - stateBefore.equityInCollateralAsset;

            // This invariant can fail when there is no shares and > 0 equity before the mint due to actors adding collateral to the LT for free
            assertLe(
                mintedSharesValue,
                deltaEquityInCollateralAsset,
                _getMintInvariantDescriptionString(
                    "The value of the shares minted must be less than or equal to the amount of equity added to the LT, due to fees and rounding.",
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );
        } else if (stateBefore.totalSupply == 0 && sharesMinted > 0) {
            uint256 mintedSharesValue = _convertToAssets(mintData.leverageToken, sharesMinted, Math.Rounding.Floor);
            assertEq(
                mintedSharesValue,
                lendingAdapter.getEquityInCollateralAsset(),
                _getMintInvariantDescriptionString(
                    "When there are no shares before the mint, the value of the shares minted must be equal to the total equity in the LT.",
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );
        }

        if (sharesMinted == 0 && stateBefore.totalSupply != 0) {
            assertGe(
                _convertToAssets(mintData.leverageToken, stateBefore.totalSupply, Math.Rounding.Floor),
                stateBefore.equityInCollateralAsset,
                _getMintInvariantDescriptionString(
                    // Share value can increase if an actor calls mint with a value too low, so that it adds collateral but does not mint any shares.
                    "When no shares are minted, the value of the total supply of shares before the mint must be greater than or equal to the total equity in the LT before the mint call.",
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );
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
                    _getMintInvariantDescriptionString(
                        "Collateral ratio after mint into an empty LT with no collateral must be equal to the initial collateral ratio, within the allowed slippage.",
                        stateBefore,
                        stateAfter,
                        mintData
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
                    _getMintInvariantDescriptionString(
                        "Collateral ratio after mint must be equal to the collateral ratio before the mint, within the allowed slippage.",
                        stateBefore,
                        stateAfter,
                        mintData
                    )
                );
            }
        }
    }

    function _getMintInvariantDescriptionString(
        string memory invariantDescription,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        LeverageManagerHandler.MintActionData memory mintData
    ) internal pure returns (string memory) {
        return string.concat(
            "Invariant Violated: ",
            invariantDescription,
            _getStateBeforeDebugString(stateBefore),
            _getStateAfterDebugString(stateAfter),
            _getMintDataDebugString(mintData)
        );
    }

    function _getMintDataDebugString(LeverageManagerHandler.MintActionData memory mintData)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            " mintData.leverageToken: ",
            Strings.toHexString(address(mintData.leverageToken)),
            " mintData.equityInCollateralAsset: ",
            Strings.toString(mintData.equityInCollateralAsset),
            " mintData.equityInDebtAsset: ",
            Strings.toString(mintData.equityInDebtAsset)
        );
    }
}
