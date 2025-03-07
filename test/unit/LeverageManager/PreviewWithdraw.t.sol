// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ExternalAction, PreviewActionData} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "./PreviewAction.t.sol";

contract PreviewWithdrawTest is PreviewActionTest {
    function testFuzz_previewWithdraw_MatchesPreviewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToWithdrawInCollateralAsset
    ) public {
        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));
        equityToWithdrawInCollateralAsset =
            uint128(bound(equityToWithdrawInCollateralAsset, 0, initialCollateral - initialDebtInCollateralAsset));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        PreviewActionData memory expectedPreviewData =
            leverageManager.exposed_previewAction(strategy, equityToWithdrawInCollateralAsset, ExternalAction.Withdraw);

        PreviewActionData memory actualPreviewData =
            leverageManager.previewWithdraw(strategy, equityToWithdrawInCollateralAsset);

        assertEq(actualPreviewData.collateral, expectedPreviewData.collateral, "Collateral to remove mismatch");
        assertEq(actualPreviewData.debt, expectedPreviewData.debt, "Debt to repay mismatch");
        assertEq(actualPreviewData.shares, expectedPreviewData.shares, "Shares after fee mismatch");
        assertEq(
            actualPreviewData.strategyFeeInCollateralAsset,
            expectedPreviewData.strategyFeeInCollateralAsset,
            "Shares fee mismatch"
        );
        assertEq(
            actualPreviewData.treasuryFeeInCollateralAsset,
            expectedPreviewData.treasuryFeeInCollateralAsset,
            "Treasury fee mismatch"
        );
    }
}
