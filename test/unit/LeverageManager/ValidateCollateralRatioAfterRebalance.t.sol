// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract ValidateCollateralRatioAfterRebalance is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(manager);
        strategy = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                targetCollateralRatio: 2 * _BASE_RATIO(),
                minCollateralRatio: _BASE_RATIO() + 1,
                maxCollateralRatio: 2 * _BASE_RATIO() + 1,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "",
            ""
        );
        vm.stopPrank();
    }

    function test_validateCollateralRatioAfterRebalance() public view {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 3 * _BASE_RATIO() - 1;

        leverageManager.exposed_validateCollateralRatioAfterRebalance(strategy, ratioBefore, ratioAfter);
        leverageManager.exposed_validateCollateralRatioAfterRebalance(
            strategy, ratioBefore, leverageManager.getStrategyTargetCollateralRatio(strategy)
        );
    }

    function test_validateCollateralRatioAfterRebalance_RevertIf_RatioInWorseState() public {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 3 * _BASE_RATIO() + 1;

        vm.expectRevert(ILeverageManager.CollateralRatioInvalid.selector);
        leverageManager.exposed_validateCollateralRatioAfterRebalance(strategy, ratioBefore, ratioAfter);
    }

    function test_validateCollateralRatioAfterRebalance_RevertIf_RatioOnTheOtherSide() public {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 2 * _BASE_RATIO() - 1;

        vm.expectRevert(ILeverageManager.ExposureDirectionChanged.selector);
        leverageManager.exposed_validateCollateralRatioAfterRebalance(strategy, ratioBefore, ratioAfter);
    }
}
