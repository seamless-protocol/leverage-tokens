// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {PreviewActionTest} from "../LeverageManager/PreviewAction.t.sol";

contract ComputeCollateralAndDebtForActionTest is PreviewActionTest {
    function test_computeCollateralAndDebtForAction_Mint() public {
        uint256 equityInCollateralAsset = 80 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 80 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Mint
        );

        assertEq(computedCollateral, 100 ether);
        assertEq(computedDebt, 20 ether);
    }

    function testFuzz_computeCollateralAndDebtForAction_Mint_WithManagementFee(uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 0, MAX_FEE));

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 equityInCollateralAsset = 80 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 80 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        // 1 year passes
        skip(SECONDS_ONE_YEAR);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Mint
        );

        // The amount of collateral and debt should be the same as before, regardless of the management fee
        assertEq(computedCollateral, 100 ether);
        assertEq(computedDebt, 20 ether);
    }

    function test_computeCollateralAndDebtForAction_Withdraw() public {
        uint256 equityInCollateralAsset = 80 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 80 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Withdraw
        );

        assertEq(computedCollateral, 100 ether);
        assertEq(computedDebt, 20 ether);
    }

    function testFuzz_computeCollateralAndDebtForAction_Withdraw_WithManagementFee(uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 0, MAX_FEE));

        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        uint256 equityInCollateralAsset = 80 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 80 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        // 1 year passes
        skip(SECONDS_ONE_YEAR);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Withdraw
        );

        // The amount of collateral and debt should be the same as before, regardless of the management fee
        assertEq(computedCollateral, 100 ether);
        assertEq(computedDebt, 20 ether);
    }

    function test_computeCollateralAndDebtForAction_Mint_TotalSupplyZero() public {
        uint256 equityInCollateralAsset = 100 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 0 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Mint
        );

        // Follows 2x target ratio, not the current ratio
        assertEq(computedCollateral, 200 ether);
        assertEq(computedDebt, 100 ether);
    }

    function test_computeCollateralAndDebtForAction_Withdraw_TotalSupplyZero() public {
        uint256 equityInCollateralAsset = 20 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 20 ether, sharesTotalSupply: 0 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Withdraw
        );

        // Follows 2x target ratio, not the current ratio
        assertEq(computedCollateral, 40 ether);
        assertEq(computedDebt, 20 ether);
    }

    function test_computeCollateralAndDebtForAction_Mint_DebtZero() public {
        uint256 equityInCollateralAsset = 100 ether;
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 0 ether, sharesTotalSupply: 20 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        (uint256 computedCollateral, uint256 computedDebt) = leverageManager.exposed_computeCollateralAndDebtForAction(
            leverageToken, equityInCollateralAsset, ExternalAction.Mint
        );

        assertEq(computedCollateral, 200 ether);
        assertEq(computedDebt, 100 ether);
    }
}
