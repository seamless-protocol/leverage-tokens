// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ExternalAction} from "src/types/DataTypes.sol";
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

        (
            uint256 expectedCollateralToAdd,
            uint256 expectedDebtToBorrow,
            uint256 expectedSharesAfterFee,
            uint256 expectedSharesFee
        ) = leverageManager.exposed_previewAction(strategy, equityToAddInCollateralAsset, ExternalAction.Deposit);

        (
            uint256 actualCollateralToAdd,
            uint256 actualDebtToBorrow,
            uint256 actualSharesAfterFee,
            uint256 actualSharesFee
        ) = leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        assertEq(actualCollateralToAdd, expectedCollateralToAdd, "Collateral to add mismatch");
        assertEq(actualDebtToBorrow, expectedDebtToBorrow, "Debt to borrow mismatch");
        assertEq(actualSharesAfterFee, expectedSharesAfterFee, "Shares after fee mismatch");
        assertEq(actualSharesFee, expectedSharesFee, "Shares fee mismatch");
    }
}
