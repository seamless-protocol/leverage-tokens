// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

import {RebalanceAdapterTest} from "./RebalanceAdapter.t.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsStateAfterRebalanceValidTest is RebalanceAdapterTest {
    MinMaxCollateralRatioRebalanceAdapterHarness public minMaxCollateralRatioRebalanceAdapter;

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

        minMaxCollateralRatioRebalanceAdapter =
            MinMaxCollateralRatioRebalanceAdapterHarness(minMaxCollateralRatioRebalanceAdapterProxy);
    }

    function testFuzz_isStateAfterRebalanceValid_ReturnsTheSameAsMinMaxCollateralRatioRebalanceAdapter(
        uint256 targetRatio,
        LeverageTokenState memory stateBefore,
        LeverageTokenState memory stateAfter
    ) public {
        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.getLeverageTokenTargetCollateralRatio.selector, leverageToken),
            abi.encode(targetRatio)
        );
        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.getLeverageTokenState.selector, leverageToken),
            abi.encode(stateAfter)
        );

        vm.startPrank(address(leverageManager));

        bool isValid = rebalanceAdapter.isStateAfterRebalanceValid(leverageToken, stateBefore);
        bool expectedIsValid =
            minMaxCollateralRatioRebalanceAdapter.isStateAfterRebalanceValid(leverageToken, stateBefore);

        vm.stopPrank();

        assertEq(isValid, expectedIsValid);
    }
}
