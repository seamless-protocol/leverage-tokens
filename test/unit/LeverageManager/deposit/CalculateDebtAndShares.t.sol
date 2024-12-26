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
            strategy: makeAddr("strategy"),
            targetRatio: 2 * _BASE_RATIO(), // 2x leverage also
            collateral: 1 ether,
            convertedCollateral: 3000 ether,
            totalEquity: 123 ether, // Not important for this test
            strategyTotalShares: 111 ether // Not important for this test
        });

        _mockState_CalculateDebtAndShares(state);

        (uint256 debt, uint256 shares) = leverageManager.exposed_calculateDebtAndShares(
            state.strategy, _getLendingAdapter(state.strategy), state.collateral
        );

        uint256 expectedDebt = 1500 ether;
        uint256 expectedEquity = 1500 ether;
        uint256 expectedShares = leverageManager.exposed_convertToShares(state.strategy, expectedEquity);

        assertEq(debt, expectedDebt);
        assertEq(shares, expectedShares);
    }

    function testFuzz_calculateDebtAndShares(CalculateDebtAndSharesState memory state) public {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO(), 200 * _BASE_RATIO());
        _mockState_CalculateDebtAndShares(state);

        address strategy = state.strategy;
        uint256 collateral = state.collateral;
        uint256 convertedCollateral = state.convertedCollateral;
        uint256 targetRatio = state.targetRatio;

        (uint256 debt, uint256 shares) =
            leverageManager.exposed_calculateDebtAndShares(strategy, _getLendingAdapter(state.strategy), collateral);

        uint256 expectedDebt = Math.mulDiv(convertedCollateral, _BASE_RATIO(), targetRatio, Math.Rounding.Ceil);
        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, convertedCollateral - expectedDebt);

        assertEq(expectedDebt, debt);
        assertEq(shares, expectedShares);
    }
}
