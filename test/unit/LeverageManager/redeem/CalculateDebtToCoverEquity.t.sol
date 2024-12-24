// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract CalculateDebtToCoverEquityTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_calculateDebtToCoverEquity_EquityLowerThanExcess() public {
        uint256 strategy = 1;
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint256 targetRatio = 2 * _BASE_RATIO(); // 2x leverage

        _mockState_CalculateExcessOfCollateral(
            CalculateExcessOfCollateralState({
                strategy: strategy,
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1000 ether;
        uint256 debtToCoverEquity = leverageManager.calculateDebtToCoverEquity(strategy, _LENDING_CONTRACT(), equity);

        assertEq(debtToCoverEquity, 0);
    }

    function test_calculateDebtToCoverEquity_EquityBiggerThanExcess() public {
        uint256 strategy = 1;
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint256 targetRatio = 2 * _BASE_RATIO(); // 2x leverage

        _mockState_CalculateExcessOfCollateral(
            CalculateExcessOfCollateralState({
                strategy: strategy,
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 equity = 1500 ether;
        uint256 debtToCoverEquity = leverageManager.calculateDebtToCoverEquity(strategy, _LENDING_CONTRACT(), equity);

        assertEq(debtToCoverEquity, 500 ether);
    }

    function testFuzz_calculateDebtToCoverEquity(CalculateExcessOfCollateralState memory state, uint128 equity)
        public
    {
        state.targetRatio = bound(state.targetRatio, _BASE_RATIO() + 1, 200 * _BASE_RATIO());

        uint256 targetRatio = state.targetRatio;

        _mockState_CalculateExcessOfCollateral(state);

        uint256 excess = leverageManager.calculateExcessOfCollateral(state.strategy, _LENDING_CONTRACT());

        uint256 debtToCoverEquity =
            leverageManager.calculateDebtToCoverEquity(state.strategy, _LENDING_CONTRACT(), equity);

        if (excess >= equity) {
            assertEq(debtToCoverEquity, 0);
        } else {
            uint256 expectedDebtToCoverEquity =
                Math.mulDiv(equity - excess, _BASE_RATIO(), targetRatio - _BASE_RATIO(), Math.Rounding.Ceil);
            assertEq(debtToCoverEquity, expectedDebtToCoverEquity);
        }
    }
}
