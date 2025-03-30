// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {PreLiquidationRebalanceAdapterTest} from "./PreLiquidationRebalanceAdapter.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsEligibleForRebalanceTest is PreLiquidationRebalanceAdapterTest {
    function test_isEligibleForRebalance_HealthFactorAboveThreshold() public {
        // Mock health factor to 1.11
        vm.mockCall(
            address(lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getHealthFactor.selector),
            abi.encode(1.11e18)
        );

        bool isEligible = adapter.isEligibleForRebalance(
            leverageToken,
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: 0}),
            address(0)
        );

        assertEq(isEligible, false);
    }

    function test_isEligibleForRebalance_HealthFactorBelowThreshold() public {
        // Mock health factor to 1.09
        vm.mockCall(
            address(lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getHealthFactor.selector),
            abi.encode(1.09e18)
        );

        bool isEligible = adapter.isEligibleForRebalance(
            leverageToken,
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: 0}),
            address(0)
        );

        assertEq(isEligible, true);
    }

    function test_isEligibleForRebalance_HealthFactorAtThreshold() public {
        // Mock health factor to 1.1
        vm.mockCall(
            address(lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getHealthFactor.selector),
            abi.encode(1.1e18)
        );

        bool isEligible = adapter.isEligibleForRebalance(
            leverageToken,
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: 0}),
            address(0)
        );

        assertEq(isEligible, true);
    }
}
