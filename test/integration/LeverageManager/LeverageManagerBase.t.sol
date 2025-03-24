// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {Strategy} from "src/Strategy.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {MorphoLendingAdapterTest} from "../MorphoLendingAdapter.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract LeverageManagerBase is IntegrationTestBase {
    function testFork_setUp() public view virtual override {
        assertEq(address(leverageManager.getStrategyCollateralAsset(strategy)), address(WETH));
        assertEq(address(leverageManager.getStrategyDebtAsset(strategy)), address(USDC));

        assertEq(leverageManager.getIsLendingAdapterUsed(address(morphoLendingAdapter)), true);
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), 2 * BASE_RATIO);
    }

    function _deposit(address caller, uint256 equityInCollateralAsset, uint256 collateralToAdd)
        internal
        returns (uint256)
    {
        deal(address(WETH), caller, collateralToAdd);
        vm.startPrank(caller);
        WETH.approve(address(leverageManager), collateralToAdd);
        uint256 shares = leverageManager.deposit(strategy, equityInCollateralAsset, 0).shares;
        vm.stopPrank();

        return shares;
    }

    function _withdraw(address caller, uint256 equityInCollateralAsset, uint256 debtToRepay)
        internal
        returns (uint256)
    {
        deal(address(USDC), caller, debtToRepay);
        vm.startPrank(caller);
        USDC.approve(address(leverageManager), debtToRepay);
        uint256 shares = leverageManager.withdraw(strategy, equityInCollateralAsset, type(uint256).max).shares;
        vm.stopPrank();

        return shares;
    }

    function getStrategyState() internal view returns (StrategyState memory) {
        return LeverageManagerHarness(address(leverageManager)).getStrategyState(strategy);
    }
}
