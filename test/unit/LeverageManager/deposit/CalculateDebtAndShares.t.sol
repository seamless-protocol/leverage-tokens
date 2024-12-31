// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract CalculateDebtAndSharesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_calculateDebtAndShares() public {
        CalculateDebtAndSharesState memory state = CalculateDebtAndSharesState({
            targetRatio: 2 * _BASE_RATIO(), // 2x leverage also
            strategyCollateral: 1 ether,
            depositAmount: 1 ether,
            depositAmountInDebtAsset: 3000 ether,
            totalEquity: 123 ether, // Not important for this test
            strategyTotalShares: 111 ether // Not important for this test
        });

        _mockState_CalculateDebtAndShares(state);

        (uint256 collateral, uint256 debt, uint256 shares) =
            leverageManager.exposed_calculateDebtAndShares(strategy, _getLendingAdapter(), state.depositAmount);

        uint256 expectedCollateral = 2 ether;
        uint256 expectedDebt = 3000 ether;
        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, state.depositAmountInDebtAsset);

        assertEq(collateral, expectedCollateral);
        assertEq(debt, expectedDebt);
        assertEq(shares, expectedShares);
    }

    function testFuzz_calculateDebtAndShares(CalculateDebtAndSharesState memory state) public {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO() + 1, 200 * _BASE_RATIO());
        _mockState_CalculateDebtAndShares(state);

        uint256 depositAmount = state.depositAmount;
        uint256 depositAmountInDebtAsset = state.depositAmountInDebtAsset;
        uint256 targetRatio = state.targetRatio;

        (uint256 collateral, uint256 debt, uint256 shares) =
            leverageManager.exposed_calculateDebtAndShares(strategy, _getLendingAdapter(), depositAmount);

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, depositAmountInDebtAsset);
        uint256 expectedCollateral =
            Math.mulDiv(depositAmount, targetRatio, targetRatio - _BASE_RATIO(), Math.Rounding.Ceil);
        uint256 expectedDebt =
            Math.mulDiv(depositAmountInDebtAsset, _BASE_RATIO(), targetRatio - _BASE_RATIO(), Math.Rounding.Floor);

        assertEq(collateral, expectedCollateral);
        assertEq(expectedDebt, debt);
        assertEq(shares, expectedShares);
    }
}
