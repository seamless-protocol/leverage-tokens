// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract ValidateEquityChangeTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_validateEquityChange() public {
        StrategyState memory stateBefore = StrategyState({
            collateralInDebtAsset: 100 ether, // not important for this test
            debt: 50 ether,
            equity: 50 ether,
            collateralRatio: 200 // not important for this test
        });
        StrategyState memory stateAfter = StrategyState({
            collateralInDebtAsset: 100 ether, // not important for this test
            debt: 70 ether,
            equity: 48 ether,
            collateralRatio: 200 // not important for this test
        });

        vm.mockCall(
            address(leverageManager.getStrategyRebalanceRewardDistributor(strategy)),
            abi.encodeWithSelector(
                IRebalanceRewardDistributor.computeRebalanceReward.selector, address(strategy), stateBefore, stateAfter
            ),
            abi.encode(2 ether)
        );

        // Should not revert because 10% is reward, debt changed for 20 ether to he can take 2 ether as reward
        leverageManager.exposed_validateEquityChange(strategy, stateBefore, stateAfter);
    }

    function test_validateEquityChange_RevertIf_ChangeTooBig() public {
        StrategyState memory stateBefore = StrategyState({
            collateralInDebtAsset: 100 ether, // not important for this test
            debt: 50 ether,
            equity: 50 ether,
            collateralRatio: 200 // not important for this test
        });
        StrategyState memory stateAfter = StrategyState({
            collateralInDebtAsset: 100 ether, // not important for this test
            debt: 70 ether,
            equity: 47 ether,
            collateralRatio: 200 // not important for this test
        });

        vm.mockCall(
            address(leverageManager.getStrategyRebalanceRewardDistributor(strategy)),
            abi.encodeWithSelector(
                IRebalanceRewardDistributor.computeRebalanceReward.selector, address(strategy), stateBefore, stateAfter
            ),
            abi.encode(2 ether)
        );

        vm.expectRevert(ILeverageManager.EquityLossTooBig.selector);
        leverageManager.exposed_validateEquityChange(strategy, stateBefore, stateAfter);
    }
}
