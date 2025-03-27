// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {RebalanceAdapterTest} from "./RebalanceAdapter.t.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsEligibleForRebalanceTest is RebalanceAdapterTest {
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

    function testFuzz_isEligibleForRebalance_ReturnsFalseIfDutchAuctionReturnsFalse(
        address caller,
        uint256 targetRatio,
        LeverageTokenState memory stateBefore
    ) public {
        vm.assume(caller != address(rebalanceAdapter));

        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.getLeverageTokenTargetCollateralRatio.selector, leverageToken),
            abi.encode(targetRatio)
        );
        vm.mockCall(
            address(leverageManager),
            abi.encodeWithSelector(ILeverageManager.getLeverageTokenState.selector, leverageToken),
            abi.encode(stateBefore)
        );

        bool isEligible = rebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, caller);
        assertEq(isEligible, false);
    }

    function testFuzz_isEligibleForRebalance_ReturnsSameAsMinMaxCollateralRatioRebalanceAdapter(
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

        bool isEligible = rebalanceAdapter.isEligibleForRebalance(leverageToken, stateBefore, address(rebalanceAdapter));
        bool expectedIsEligible = minMaxCollateralRatioRebalanceAdapter.isEligibleForRebalance(
            leverageToken, stateBefore, address(rebalanceAdapter)
        );
        assertEq(isEligible, expectedIsEligible);
    }
}
