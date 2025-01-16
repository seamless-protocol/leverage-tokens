// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
/*

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract GetStrategyCollateralRatioAndExcessTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_getStrategyCollateralRatioAndExcess_ExcessExists() public {
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x collateral ratio

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        assertEq(collateralRatio, 3 * _BASE_RATIO());
        assertEq(excess, 1000 ether);
    }

    function test_getStrategyCollateralRatioAndExcess_ExcessDoesNotExist() public {
        uint128 collateralInDebt = 1999 ether;
        uint128 debt = 1000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x collateral ratio

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        assertEq(collateralRatio, 1_9990_0000);
        assertEq(excess, 0);
    }

    function test_getStrategyCollateralRatioAndExcess_RoundedDown() public {
        uint128 collateralInDebt = 2;
        uint128 debt = 1;
        uint128 targetRatio = uint128(3 * _BASE_RATIO() / 2); // 1.5x collateral ratio

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        assertEq(collateralRatio, 2 * _BASE_RATIO());
        assertEq(excess, 0);
    }

    function testFuzz_getStrategyCollateralRatioAndExcess_ExcessExists(
        CalculateStrategyCollateralRatioAndExcessState memory state
    ) public {
        vm.assume(state.debt > 0);
        vm.assume(state.targetRatio > _BASE_RATIO());

        uint256 collateralInDebt = state.collateralInDebt;
        uint256 debt = state.debt;
        uint256 targetRatio = state.targetRatio;

        vm.assume(collateralInDebt > debt * targetRatio / _BASE_RATIO() + 1);

        _mockState_CalculateStrategyCollateralRatioAndExcess(state);

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        uint256 expectedCollateralRatio = Math.mulDiv(collateralInDebt, _BASE_RATIO(), debt, Math.Rounding.Floor);
        assertEq(collateralRatio, expectedCollateralRatio);

        uint256 expectedExcess = collateralInDebt - Math.mulDiv(debt, targetRatio, _BASE_RATIO(), Math.Rounding.Ceil);
        assertEq(excess, expectedExcess);
    }

    function testFuzz_getStrategyCollateralRatioAndExcess_ExcessDoesNotExist(
        CalculateStrategyCollateralRatioAndExcessState memory state
    ) public {
        vm.assume(state.targetRatio > _BASE_RATIO());
        vm.assume(state.debt > 0);
        vm.assume(state.collateralInDebt < uint256(state.debt) * state.targetRatio / _BASE_RATIO() + 1);

        _mockState_CalculateStrategyCollateralRatioAndExcess(state);

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        uint256 expectedCollateralRatio =
            Math.mulDiv(state.collateralInDebt, _BASE_RATIO(), state.debt, Math.Rounding.Floor);

        assertEq(collateralRatio, expectedCollateralRatio);
        assertEq(excess, 0);
    }

    function testFuzz_getStrategyCollateralRatioAndExcess_DebtIsZero(
        CalculateStrategyCollateralRatioAndExcessState memory state
    ) public {
        state.debt = 0;
        vm.assume(state.targetRatio > _BASE_RATIO());

        _mockState_CalculateStrategyCollateralRatioAndExcess(state);

        (uint256 collateralRatio, uint256 excess) =
            leverageManager.exposed_getStrategyCollateralRatioAndExcess(strategy, _getLendingAdapter());

        assertEq(collateralRatio, type(uint256).max);
        assertEq(excess, state.collateralInDebt);
    }
}
*/
