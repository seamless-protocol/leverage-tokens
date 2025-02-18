// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "test/unit/LeverageManager/LeverageManagerBase.t.sol";

contract CalculateCollateralAndDebtToCoverEquityTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_calculateCollateralAndDebtToCoverEquity_DepositOverCollateralized() public {
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

        // Strategy is over collateral which means that optimization can not be done so user need to deposit collateral and receive debt based on target ratio
        uint256 expectedDebt = 1000 ether;
        uint256 expectedCollateral = 2000 ether;
        uint256 debtToCollateral = 3 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        _mockConvertDebt(expectedCollateral, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Deposit
        );

        assertEq(collateral, debtToCollateral);
        assertEq(debtToCoverEquity, expectedDebt);
    }

    function test_calculateCollateralAndDebtToCoverEquity_DepositUnderCollateralized_EquityCoversDeficit() public {
        uint128 collateralInDebt = 3500 ether;
        uint128 debt = 2000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 500 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(equity, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Deposit
        );

        assertEq(debtToCoverEquity, 0);
        assertEq(collateral, debtToCollateral);
    }

    function test_calculateCollateralAndDebtToCoverEquity_DepositUnderCollateralized_EquityDoesNotCoverDeficit()
        public
    {
        uint128 collateralInDebt = 3500 ether;
        uint128 debt = 2000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1000 ether;

        uint256 expectedDebt = 500 ether;
        uint256 expectedCollateral = 1500 ether; // 500 equity + 1000 collateral to cover 500 debt

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(expectedCollateral, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Deposit
        );

        assertEq(debtToCoverEquity, expectedDebt);
        assertEq(collateral, debtToCollateral);
    }

    function test_calculateCollateralAndDebtToCoverEquity_RedeemOverCollateralized_ExcessCoversEquity() public {
        uint128 collateralInDebt = 4500 ether;
        uint128 debt = 2000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 500 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(equity, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Redeem
        );

        assertEq(debtToCoverEquity, 0);
        assertEq(collateral, debtToCollateral);
    }

    function test_calculateCollateralAndDebtToCoverEquity_RedeemOverCollateralized_ExcessDoesNotCoverEquity() public {
        uint128 collateralInDebt = 4500 ether;
        uint128 debt = 2000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1000 ether;

        uint256 expectedCollateral = 1500 ether;
        uint256 expectedDebt = 500 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(expectedCollateral, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Redeem
        );

        assertEq(debtToCoverEquity, expectedDebt);
        assertEq(collateral, debtToCollateral);
    }

    function test_calculateCollateralAndDebtToCoverEquity_RedeemUnderCollateralized() public {
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 2000 ether;
        uint128 targetRatio = uint128(2 * _BASE_RATIO()); // 2x leverage

        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 500 ether;

        uint256 expectedCollateral = 1500 ether;
        uint256 expectedDebt = 1000 ether;

        // Mocks exchange rate. Not important for this test bu it is important that call to lending adapter is mocked with correct call parameters
        uint256 debtToCollateral = 3 ether;
        _mockConvertDebt(expectedCollateral, debtToCollateral);

        (uint256 collateral, uint256 debtToCoverEquity) = leverageManager
            .exposed_calculateCollateralAndDebtToCoverEquity(
            strategy, _getLendingAdapter(), equity, IFeeManager.Action.Redeem
        );

        assertEq(debtToCoverEquity, expectedDebt);
        assertEq(collateral, debtToCollateral);
    }
}
