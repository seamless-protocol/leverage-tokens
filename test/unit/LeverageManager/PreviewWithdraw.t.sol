// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ExternalAction} from "src/types/DataTypes.sol";
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

        (
            uint256 expectedCollateralToRemove,
            uint256 expectedDebtToRepay,
            uint256 expectedSharesAfterFee,
            uint256 expectedSharesFee
        ) = leverageManager.exposed_previewAction(strategy, equityToWithdrawInCollateralAsset, ExternalAction.Withdraw);

        (
            uint256 actualCollateralToRemove,
            uint256 actualDebtToRepay,
            uint256 actualSharesAfterFee,
            uint256 actualSharesFee
        ) = leverageManager.previewWithdraw(strategy, equityToWithdrawInCollateralAsset);

        assertEq(actualCollateralToRemove, expectedCollateralToRemove, "Collateral to remove mismatch");
        assertEq(actualDebtToRepay, expectedDebtToRepay, "Debt to repay mismatch");
        assertEq(actualSharesAfterFee, expectedSharesAfterFee, "Shares after fee mismatch");
        assertEq(actualSharesFee, expectedSharesFee, "Shares fee mismatch");
    }
}
