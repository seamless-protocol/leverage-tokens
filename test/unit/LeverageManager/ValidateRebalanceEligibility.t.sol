// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Internal imports
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract ValidateRebalanceEligibility is LeverageManagerBaseTest {
    uint256 public minRatio;
    uint256 public maxRatio;
    uint256 public targetRatio;

    function setUp() public override {
        super.setUp();

        minRatio = _BASE_RATIO();
        maxRatio = 3 * _BASE_RATIO();
        targetRatio = 2 * _BASE_RATIO();

        vm.startPrank(manager);
        strategy = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: minRatio,
                maxCollateralRatio: maxRatio,
                targetCollateralRatio: targetRatio,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "Strategy",
            "STR"
        );
        vm.stopPrank();
    }

    function test_validateRebalanceEligibility() public view {
        // Should not revert because current ratio is lower than min ratio
        leverageManager.exposed_validateRebalanceEligibility(strategy, minRatio - 1);

        // Should not revert because current ratio is higher than max ratio
        leverageManager.exposed_validateRebalanceEligibility(strategy, maxRatio + 1);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateRebalanceEligibility_RevertIf_RatioInProperState(uint256 currRatio) public {
        vm.assume(currRatio >= minRatio && currRatio <= maxRatio);
        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.StrategyNotEligibleForRebalance.selector, strategy));
        leverageManager.exposed_validateRebalanceEligibility(strategy, currRatio);
    }
}
