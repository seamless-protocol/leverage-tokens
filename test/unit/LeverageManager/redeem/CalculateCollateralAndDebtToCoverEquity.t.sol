// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract CalculateCollateralAndDebtToCoverEquityTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_calculateCollateralAndDebtToCoverEquity_EquityLowerThanExcess() public {
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1000 ether;
        uint256 debtToCollateral = 3 ether;
        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        _mockConvertDebt(equity, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) =
            leverageManager.exposed_calculateCollateralAndDebtToCoverEquity(strategy, _getLendingAdapter(), equity);

        assertEq(collateral, debtToCollateral);
        assertEq(debtToCoverEquity, 0);
    }

    function test_calculateCollateralAndDebtToCoverEquity_EquityBiggerThanExcess_ExcessExists() public {
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1500 ether;
        uint256 expectedDebtToCoverEquity = 500 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(equity + expectedDebtToCoverEquity, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) =
            leverageManager.exposed_calculateCollateralAndDebtToCoverEquity(strategy, _getLendingAdapter(), equity);

        assertEq(debtToCoverEquity, expectedDebtToCoverEquity);
        assertEq(collateral, debtToCollateral);
    }

    function test_calculateCollateralAndDebtToCoverEquity_ExcessDoesNotExist() public {
        uint128 collateralInDebt = 1600 ether;
        uint128 debt = 1000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 300 ether;
        uint256 expectedDebtToCoverEquity = 500 ether; // Expected to cover equity based on current ratio not target

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(equity + expectedDebtToCoverEquity, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) =
            leverageManager.exposed_calculateCollateralAndDebtToCoverEquity(strategy, _getLendingAdapter(), equity);

        assertEq(debtToCoverEquity, expectedDebtToCoverEquity);
        assertEq(collateral, debtToCollateral);
    }
}
