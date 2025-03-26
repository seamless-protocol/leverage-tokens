// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Internal imports
import {IMinMaxCollateralRatioRebalanceAdapter} from "src/interfaces/IMinMaxCollateralRatioRebalanceAdapter.sol";
import {MinMaxCollateralRatioRebalanceAdapterTest} from "./MinMaxCollateralRatioRebalanceAdapter.t.sol";
import {MinMaxCollateralRatioRebalanceAdapterHarness} from
    "test/unit/harness/MinMaxCollateralRatioRebalanceAdapterHarness.t.sol";
import {MinMaxCollateralRatioRebalanceAdapter} from "src/rebalance/MinMaxCollateralRatioRebalanceAdapter.sol";

contract InitializeTest is MinMaxCollateralRatioRebalanceAdapterTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize(uint256 minCollateralRatio, uint256 maxCollateralRatio) public {
        vm.assume(minCollateralRatio < maxCollateralRatio);

        address rebalanceModuleImplementation = address(new MinMaxCollateralRatioRebalanceAdapterHarness());
        address rebalanceModuleProxy = UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(
                MinMaxCollateralRatioRebalanceAdapterHarness.initialize.selector, minCollateralRatio, maxCollateralRatio
            )
        );
        MinMaxCollateralRatioRebalanceAdapterHarness newModule =
            MinMaxCollateralRatioRebalanceAdapterHarness(rebalanceModuleProxy);

        assertEq(newModule.getLeverageTokenMinCollateralRatio(), minCollateralRatio);
        assertEq(newModule.getLeverageTokenMaxCollateralRatio(), maxCollateralRatio);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize_RevertIf_MinCollateralRatioTooHigh(
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) public {
        vm.assume(minCollateralRatio > maxCollateralRatio);

        address rebalanceModuleImplementation = address(new MinMaxCollateralRatioRebalanceAdapterHarness());

        vm.expectRevert(IMinMaxCollateralRatioRebalanceAdapter.MinCollateralRatioTooHigh.selector);
        UnsafeUpgrades.deployUUPSProxy(
            rebalanceModuleImplementation,
            abi.encodeWithSelector(
                MinMaxCollateralRatioRebalanceAdapterHarness.initialize.selector, minCollateralRatio, maxCollateralRatio
            )
        );
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_initialize_RevertIf_AlreadyInitialized(uint256 minCollateralRatio, uint256 maxCollateralRatio)
        public
    {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rebalanceModule.initialize(minCollateralRatio, maxCollateralRatio);
    }
}
