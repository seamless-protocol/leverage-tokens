// SPDX-License-Identifier: UNLICENSED
/*
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract ValidateCollateralRatioAfterRebalance is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            CollateralRatios({
                targetCollateralRatio: 2 * _BASE_RATIO(),
                minCollateralRatio: _BASE_RATIO() + 1,
                maxCollateralRatio: 2 * _BASE_RATIO() + 1
            })
        );
        vm.stopPrank();
    }

    function test_validateCollateralRatioAfterAction() public view {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 3 * _BASE_RATIO() - 1;

        leverageManager.exposed_validateCollateralRatioAfterAction(strategy, ratioBefore, ratioAfter);
        leverageManager.exposed_validateCollateralRatioAfterAction(
            strategy, ratioBefore, leverageManager.getStrategyTargetCollateralRatio(strategy)
        );
    }

    function test_validateCollateralRatioAfterAction_RevertIf_RatioInWorstState() public {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 3 * _BASE_RATIO() + 1;

        vm.expectRevert(ILeverageManager.CollateralRatioInvalid.selector);
        leverageManager.exposed_validateCollateralRatioAfterAction(strategy, ratioBefore, ratioAfter);
    }

    function test_validateCollateralRatioAfterAction_RevertIf_RatioOnTheOtherSide() public {
        uint256 ratioBefore = 3 * _BASE_RATIO();
        uint256 ratioAfter = 2 * _BASE_RATIO() - 1;

        vm.expectRevert(ILeverageManager.ExposureDirectionChanged.selector);
        leverageManager.exposed_validateCollateralRatioAfterAction(strategy, ratioBefore, ratioAfter);
    }
}

*/
