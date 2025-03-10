// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ActionData, ExternalAction} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "./PreviewAction.t.sol";

import {console2} from "forge-std/console2.sol";

contract PreviewWithdrawTest is PreviewActionTest {
    function testFuzz_previewWithdraw_MatchesPreviewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToWithdrawInCollateralAsset,
        uint16 treasuryFee
    ) public {
        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));

        treasuryFee = uint16(bound(treasuryFee, 0, 1e4));
        _setTreasuryActionFee(ExternalAction.Withdraw, treasuryFee);

        uint256 maxWithdrawableEquity =
            Math.mulDiv(initialCollateral - initialDebtInCollateralAsset, 1e4 - treasuryFee, 1e4);

        equityToWithdrawInCollateralAsset = uint128(bound(equityToWithdrawInCollateralAsset, 0, maxWithdrawableEquity));

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        ActionData memory previewActionData =
            leverageManager.exposed_previewAction(strategy, equityToWithdrawInCollateralAsset, ExternalAction.Withdraw);

        ActionData memory actualPreviewData =
            leverageManager.previewWithdraw(strategy, equityToWithdrawInCollateralAsset);

        assertEq(
            actualPreviewData.collateral,
            previewActionData.collateral > previewActionData.treasuryFee
                ? previewActionData.collateral - previewActionData.treasuryFee
                : 0,
            "Collateral to remove mismatch"
        );
        assertEq(actualPreviewData.debt, previewActionData.debt, "Debt to repay mismatch");
        assertEq(actualPreviewData.shares, previewActionData.shares, "Shares after fee mismatch");
        assertEq(actualPreviewData.strategyFee, previewActionData.strategyFee, "Shares fee mismatch");
        assertEq(
            actualPreviewData.treasuryFee,
            previewActionData.collateral <= previewActionData.treasuryFee
                ? previewActionData.collateral
                : previewActionData.treasuryFee,
            "Treasury fee mismatch"
        );
        assertEq(actualPreviewData.equity, previewActionData.equity, "Equity mismatch");
    }
}
