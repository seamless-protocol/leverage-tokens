// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

import {RebalanceAdapterTest} from "./RebalanceAdapter.t.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {PreLiquidationRebalanceAdapterHarness} from "test/unit/harness/PreLiquidationRebalanceAdapterHarness.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";

contract IsStateAfterRebalanceValidTest is RebalanceAdapterTest {
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
                PreLiquidationRebalanceAdapterHarness.initialize.selector, healthFactorThreshold, rebalanceReward
            )
        );

        minMaxCollateralRatioRebalanceAdapter =
            MinMaxCollateralRatioRebalanceAdapterHarness(minMaxCollateralRatioRebalanceAdapterProxy);
        preLiquidationRebalanceAdapter = PreLiquidationRebalanceAdapterHarness(preLiquidationRebalanceAdapterProxy);

        preLiquidationRebalanceAdapter.setLeverageManager(leverageManager);
        minMaxCollateralRatioRebalanceAdapter.mock_setLeverageManager(leverageManager);
    }

    function testFuzz_isStateAfterRebalanceValid(
        uint256 targetRatio,
        LeverageTokenState memory stateBefore,
        LeverageTokenState memory stateAfter,
        uint256 currentHealthFactor,
        uint256 liquidationPenalty
    ) public {
        liquidationPenalty = bound(liquidationPenalty, 0, 1e18);
        _mockLeverageTokenState(targetRatio, stateAfter, currentHealthFactor);

        vm.mockCall(
            address(leverageManager.getLeverageTokenLendingAdapter(leverageToken)),
            abi.encodeWithSelector(ILendingAdapter.getLiquidationPenalty.selector),
            abi.encode(liquidationPenalty)
        );

        bool isValid = rebalanceAdapter.isStateAfterRebalanceValid(leverageToken, stateBefore);
        bool expectedIsValid = minMaxCollateralRatioRebalanceAdapter.isStateAfterRebalanceValid(
            leverageToken, stateBefore
        ) && preLiquidationRebalanceAdapter.isStateAfterRebalanceValid(leverageToken, stateBefore);

        assertEq(isValid, expectedIsValid);
    }
}
