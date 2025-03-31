// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {RebalanceAdapterTest} from "./RebalanceAdapter.t.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {PreLiquidationRebalanceAdapterHarness} from "test/unit/harness/PreLiquidationRebalanceAdapterHarness.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsEligibleForRebalanceTest is RebalanceAdapterTest {
    MinMaxCollateralRatioRebalanceAdapterHarness public minMaxCollateralRatioRebalanceAdapter;
    PreLiquidationRebalanceAdapterHarness public preLiquidationRebalanceAdapter;

    function setUp() public override {
        super.setUp();

        MinMaxCollateralRatioRebalanceAdapterHarness minMaxCollateralRatioRebalanceAdapterHarness =
            new MinMaxCollateralRatioRebalanceAdapterHarness();
        address minMaxCollateralRatioRebalanceAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            address(minMaxCollateralRatioRebalanceAdapterHarness),
            abi.encodeWithSelector(
                MinMaxCollateralRatioRebalanceAdapterHarness.initialize.selector, minCollateralRatio, maxCollateralRatio
            )
        );

        PreLiquidationRebalanceAdapterHarness preLiquidationRebalanceAdapterHarness =
            new PreLiquidationRebalanceAdapterHarness();
        address preLiquidationRebalanceAdapterProxy = UnsafeUpgrades.deployUUPSProxy(
            address(preLiquidationRebalanceAdapterHarness),
            abi.encodeWithSelector(
                PreLiquidationRebalanceAdapterHarness.initialize.selector, collateralRatioThreshold, rebalanceReward
            )
        );

        minMaxCollateralRatioRebalanceAdapter =
            MinMaxCollateralRatioRebalanceAdapterHarness(minMaxCollateralRatioRebalanceAdapterProxy);
        preLiquidationRebalanceAdapter = PreLiquidationRebalanceAdapterHarness(preLiquidationRebalanceAdapterProxy);

        preLiquidationRebalanceAdapter.setLeverageManager(leverageManager);
        minMaxCollateralRatioRebalanceAdapter.mock_setLeverageManager(leverageManager);
    }

    function testFuzz_isEligibleForRebalance_ReturnsTheSameAsPreLiquidationRebalanceAdapter_IfDutchAuctionReturnsFalse(
        address caller,
        uint256 targetRatio,
        LeverageTokenState memory stateBefore,
        LeverageTokenState memory stateAfter
    ) public {
        vm.assume(caller != address(rebalanceAdapter));

        _mockLeverageTokenState(targetRatio, stateAfter);

        bool isEligible = rebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, caller);
        bool expectedIsEligible =
            preLiquidationRebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, caller);
        assertEq(isEligible, expectedIsEligible);
    }

    function testFuzz_isEligibleForRebalance_ReturnsSameAsMinMaxCollateralRatioRebalanceAdapter(
        uint256 targetRatio,
        LeverageTokenState memory stateBefore,
        LeverageTokenState memory stateAfter
    ) public {
        vm.assume(stateBefore.collateralRatio >= 1.3e8);
        _mockLeverageTokenState(targetRatio, stateAfter);

        bool isEligible = rebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, address(rebalanceAdapter));
        bool expectedIsEligible = minMaxCollateralRatioRebalanceAdapter.isEligibleForRebalance(
            leverageToken, stateBefore, address(rebalanceAdapter)
        );
        assertEq(isEligible, expectedIsEligible);
    }
}
