// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ExternalAction, PreviewActionData} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "./PreviewAction.t.sol";

contract PreviewDepositTest is PreviewActionTest {
    function testFuzz_previewDeposit_MatchesPreviewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset
    ) public {
        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        PreviewActionData memory expectedPreviewData =
            leverageManager.exposed_previewAction(strategy, equityToAddInCollateralAsset, ExternalAction.Deposit);

        PreviewActionData memory actualPreviewData =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        assertEq(actualPreviewData.collateral, expectedPreviewData.collateral, "Collateral to add mismatch");
        assertEq(actualPreviewData.debt, expectedPreviewData.debt, "Debt to borrow mismatch");
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
