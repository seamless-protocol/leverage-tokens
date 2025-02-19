// SPDX-License-Identifier: UNLICENSED
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

contract ValidateRebalanceEligibility is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_validateRebalanceEligibility() public {
        // Should not revert because current ratio is lower than min ratio
        uint256 targetRatio = 2 * _BASE_RATIO();
        uint256 minRatio = _BASE_RATIO();
        uint256 maxRatio = 3 * _BASE_RATIO();

        vm.startPrank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            CollateralRatios({
                targetCollateralRatio: targetRatio,
                minCollateralRatio: minRatio,
                maxCollateralRatio: maxRatio
            })
        );
        vm.stopPrank();

        leverageManager.exposed_validateRebalanceEligibility(strategy, minRatio - 1);

        // Should not revert because current ratio is higher than max ratio
        leverageManager.exposed_validateRebalanceEligibility(strategy, maxRatio + 1);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateRebalanceEligibility_RevertIf_RatioInProperState(uint256 currRatio) public {
        // Should revert because current ratio is equal to min ratio
        uint256 targetRatio = 2 * _BASE_RATIO();
        uint256 minRatio = _BASE_RATIO();
        uint256 maxRatio = 3 * _BASE_RATIO();

        vm.assume(currRatio >= minRatio && currRatio <= maxRatio);

        vm.startPrank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            CollateralRatios({
                targetCollateralRatio: targetRatio,
                minCollateralRatio: minRatio,
                maxCollateralRatio: maxRatio
            })
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.StrategyNotEligibleForRebalance.selector, strategy));
        leverageManager.exposed_validateRebalanceEligibility(strategy, currRatio);
    }
}
