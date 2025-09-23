// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {stdMath} from "forge-std/StdMath.sol";

// Dependency imports
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

        // Check if lendingAdapter.convertCollateralToDebtAsset(total collateral) will overflow. If it does,
        // LeverageManager.getLeverageTokenState will overflow when calculating collateral ratio.
        // Note: Mints can still occur if ILendingAdapter.convertCollateralToDebtAsset(leverageToken collateral) overflows,
        //       because the logic in LeverageManager does not convert collateral to debt during a mint.
        if (type(uint256).max / IOracle(oracle).price() >= lendingAdapter.getCollateral()) {
            LeverageTokenState memory stateAfter = leverageManager.getLeverageTokenState(mintData.leverageToken);

            _assertSharesInvariants(lendingAdapter, mintData, stateBefore, stateAfter);
            _assertCollateralRatioInvariants(lendingAdapter, mintData, stateBefore, stateAfter, rebalanceAdapter);
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

        _assertBeforeSharesValue(stateBefore, mintData, stateAfter);
        _assertMintedSharesValue(lendingAdapter, mintData, stateBefore, stateAfter, sharesMinted);
    }

    function _assertCollateralRatioInvariants(
        ILendingAdapter lendingAdapter,
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        IRebalanceAdapterBase rebalanceAdapter
    ) internal view {
        _assertInitialCollateralRatio(mintData, stateBefore, stateAfter, rebalanceAdapter);
        _assertCollateralRatioChange(lendingAdapter, stateBefore, stateAfter, mintData);
    }

    function _assertBeforeSharesValue(
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageTokenState memory stateAfter
    ) internal view {
        if (stateBefore.totalSupply != 0) {
            assertGe(
                leverageManager.convertToAssets(stateBefore.leverageToken, stateBefore.totalSupply),
                stateBefore.equityInCollateralAsset,
                _getMintInvariantDescriptionString(
                    "The value of the total supply of shares before the mint must be greater than or equal to their value before the mint.",
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );
        }
    }

    function _assertMintedSharesValue(
        ILendingAdapter lendingAdapter,
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        uint256 sharesMinted
    ) internal view {
        if (sharesMinted != 0) {
            uint256 mintedSharesValue = leverageManager.convertToAssets(mintData.leverageToken, sharesMinted);

            if (stateBefore.totalSupply != 0) {
                uint256 deltaEquityInCollateralAsset =
                    lendingAdapter.getEquityInCollateralAsset() - stateBefore.equityInCollateralAsset;

                assertLe(
                    mintedSharesValue,
                    deltaEquityInCollateralAsset,
                    _getMintInvariantDescriptionString(
                        "The value of the shares minted must be less than or equal to the amount of equity added to the LT, due to rounding and the mint token action fee.",
                        stateBefore,
                        stateAfter,
                        mintData
                    )
                );
            } else {
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
        }
    }

    function _assertInitialCollateralRatio(
        LeverageManagerHandler.MintActionData memory mintData,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        IRebalanceAdapterBase rebalanceAdapter
    ) internal view {
        bool isInitialStateEmpty = stateBefore.totalSupply == 0 && stateBefore.collateral == 0;

        if (isInitialStateEmpty && mintData.shares != 0) {
            uint256 initialCollateralRatio =
                rebalanceAdapter.getLeverageTokenInitialCollateralRatio(mintData.leverageToken);

            if (stateAfter.debt > 0) {
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    initialCollateralRatio,
                    _getAllowedCollateralRatioSlippage(stateAfter.equity),
                    _getMintInvariantDescriptionString(
                        "Collateral ratio after minting an LT with 0 collateral and 0 total supply must be equal to the specified initial collateral ratio, within the allowed slippage.",
                        stateBefore,
                        stateAfter,
                        mintData
                    )
                );
            } else {
                if (stateBefore.debt == 0) {
                    // Debt borrowed can be zero on an initial mint if the amount of collateral added * the base ratio is less
                    // than the initial collateral ratio, calculated when determining the amount of debt to borrow in the
                    // LeverageManager logic when the initial collateral and debt are both zero (debt = collateral * BASE_RATIO / initialCollateralRatio).
                    // It may also be zero if that amount converted to debt using the underlying market oracle results in zero.
                    ILendingAdapter lendingAdapter =
                        leverageManager.getLeverageTokenLendingAdapter(mintData.leverageToken);
                    uint256 collateralAdded = lendingAdapter.getCollateral();
                    assertTrue(
                        collateralAdded * BASE_RATIO < initialCollateralRatio
                            || lendingAdapter.convertCollateralToDebtAsset(
                                collateralAdded * BASE_RATIO / initialCollateralRatio
                            ) == 0,
                        _getMintInvariantDescriptionString(
                            "The amount of collateral added multiplied by the base ratio must be less than the initial collateral ratio or the debt in collateral asset converted to debt using the underlying market oracle must result in zero if the debt borrowed for the mint is zero.",
                            stateBefore,
                            stateAfter,
                            mintData
                        )
                    );
                }

                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    _getMintInvariantDescriptionString(
                        "Collateral ratio after minting an LT with 0 collateral and 0 total supply must be equal to type(uint256).max if the debt borrowed for the mint is zero.",
                        stateBefore,
                        stateAfter,
                        mintData
                    )
                );
            }
        }
    }

    function _assertCollateralRatioChange(
        ILendingAdapter lendingAdapter,
        LeverageManagerHandler.LeverageTokenStateData memory stateBefore,
        LeverageTokenState memory stateAfter,
        LeverageManagerHandler.MintActionData memory mintData
    ) internal view {
        if (stateBefore.totalSupply != 0 && stateBefore.debt != 0) {
            uint256 debtInCollateralAsset = lendingAdapter.convertDebtToCollateralAsset(lendingAdapter.getDebt());
            uint256 collateralRatioUsingDebtNormalized = debtInCollateralAsset > 0
                ? Math.mulDiv(lendingAdapter.getCollateral(), BASE_RATIO, debtInCollateralAsset, Math.Rounding.Floor)
                : type(uint256).max;

            uint256 allowedSlippage =
                _getAllowedCollateralRatioSlippage(Math.min(stateBefore.collateral, stateBefore.debt));

            // Due to oracle price, it's possible for the collateral ratio to be 0 in these tests. In those cases,
            // the % difference will be 100%. Also, stdMath.percentDelta will overflow due to division by zero.
            if (stateBefore.collateralRatio != 0 && stateBefore.collateralRatioUsingDebtNormalized != 0) {
                bool isCollateralRatioWithinAllowedSlippage = stdMath.percentDelta(
                    stateAfter.collateralRatio, stateBefore.collateralRatio
                ) <= allowedSlippage
                    || stdMath.percentDelta(
                        collateralRatioUsingDebtNormalized, stateBefore.collateralRatioUsingDebtNormalized
                    ) <= allowedSlippage;

                assertTrue(
                    isCollateralRatioWithinAllowedSlippage,
                    _getMintInvariantDescriptionString(
                        "Collateral ratio after mint must be equal to the collateral ratio before the mint, within the allowed slippage.",
                        stateBefore,
                        stateAfter,
                        mintData
                    )
                );
            }

            bool isCollateralRatioGeBefore = collateralRatioUsingDebtNormalized
                >= stateBefore.collateralRatioUsingDebtNormalized
                || stateAfter.collateralRatio >= stateBefore.collateralRatio;
            assertTrue(
                isCollateralRatioGeBefore,
                _getMintInvariantDescriptionString(
                    string.concat(
                        "Collateral ratio after mint must be greater than or equal to the collateral ratio before the mint.",
                        " Collateral ratio calculated by normalizing collateral to the debt asset: ",
                        Strings.toString(collateralRatioUsingDebtNormalized),
                        " Collateral ratio calculated by normalizing debt to the collateral asset: ",
                        Strings.toString(stateAfter.collateralRatio)
                    ),
                    stateBefore,
                    stateAfter,
                    mintData
                )
            );
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
            " mintData.shares: ",
            Strings.toString(mintData.shares)
        );
    }
}
