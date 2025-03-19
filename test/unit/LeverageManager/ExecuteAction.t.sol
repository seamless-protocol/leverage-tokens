// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ActionType} from "src/types/DataTypes.sol";

contract ExecuteActionTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createNewStrategy(
            manager,
            ILeverageManager.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: _BASE_RATIO(),
                maxCollateralRatio: _BASE_RATIO() + 2,
                targetCollateralRatio: _BASE_RATIO() + 1,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0)),
                strategyDepositFee: 0,
                strategyWithdrawFee: 0
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_executeLendingAdapterAction_AddCollateral(uint256 amount) public {
        collateralToken.mint(address(leverageManager), amount);
        leverageManager.exposed_executeLendingAdapterAction(strategy, ActionType.AddCollateral, amount);

        assertEq(collateralToken.balanceOf(address(leverageManager)), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager.getStrategyLendingAdapter(strategy))), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function tesFuzz_executeLendingAdapterAction_RemoveCollateral(uint256 amount) public {
        leverageManager.exposed_executeLendingAdapterAction(strategy, ActionType.RemoveCollateral, amount);

        assertEq(collateralToken.balanceOf(address(leverageManager)), amount);
        assertEq(collateralToken.balanceOf(address(leverageManager.getStrategyLendingAdapter(strategy))), 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_executeLendingAdapterAction_Repay(uint256 amount) public {
        vm.prank(address(leverageManager));
        lendingAdapter.borrow(amount);

        leverageManager.exposed_executeLendingAdapterAction(strategy, ActionType.Repay, amount);

        assertEq(debtToken.balanceOf(address(leverageManager)), 0);
        assertEq(debtToken.balanceOf(address(leverageManager.getStrategyLendingAdapter(strategy))), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_executeLendingAdapterAction_Borrow(uint256 amount) public {
        leverageManager.exposed_executeLendingAdapterAction(strategy, ActionType.Borrow, amount);

        assertEq(debtToken.balanceOf(address(leverageManager)), amount);
        assertEq(debtToken.balanceOf(address(leverageManager.getStrategyLendingAdapter(strategy))), 0);
    }
}
