// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// External imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract ComputeEquityFeesTest is FeeManagerBaseTest {
    address public treasury = makeAddr("treasury");
    IStrategy public strategy = IStrategy(makeAddr("strategy"));

    function setUp() public override {
        super.setUp();

        vm.prank(feeManagerRole);
        feeManager.setTreasury(treasury);
    }

    function test_computeEquityFees_Deposit() public {
        ExternalAction action = ExternalAction.Deposit;
        uint256 equity = 1 ether;
        uint256 depositTreasuryFee = 100;
        uint256 depositStrategyFee = 200;
        uint256 withdrawTreasuryFee = 300;
        uint256 withdrawStrategyFee = 400;
        _setFees(depositTreasuryFee, depositStrategyFee, withdrawTreasuryFee, withdrawStrategyFee);

        (uint256 equityForStrategyAfterFees, uint256 equityForSharesAfterFees, uint256 strategyFee, uint256 treasuryFee)
        = feeManager.exposed_computeEquityFees(strategy, equity, action);

        uint256 expectedStrategyFee = Math.mulDiv(equity, depositStrategyFee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        uint256 expectedTreasuryFee = Math.mulDiv(equity, depositTreasuryFee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        assertEq(strategyFee, expectedStrategyFee);
        assertEq(treasuryFee, expectedTreasuryFee);

        assertEq(equityForStrategyAfterFees, equity - expectedTreasuryFee);
        assertEq(equityForSharesAfterFees, equity - (expectedTreasuryFee + expectedStrategyFee));
    }

    function test_computeEquityFees_Withdraw() public {
        ExternalAction action = ExternalAction.Withdraw;
        uint256 equity = 1 ether;
        uint256 depositTreasuryFee = 100;
        uint256 depositStrategyFee = 200;
        uint256 withdrawTreasuryFee = 300;
        uint256 withdrawStrategyFee = 400;
        _setFees(depositTreasuryFee, depositStrategyFee, withdrawTreasuryFee, withdrawStrategyFee);

        (uint256 equityForStrategyAfterFees, uint256 equityForSharesAfterFees, uint256 strategyFee, uint256 treasuryFee)
        = feeManager.exposed_computeEquityFees(strategy, equity, action);

        uint256 expectedStrategyFee = Math.mulDiv(equity, withdrawStrategyFee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        uint256 expectedTreasuryFee = Math.mulDiv(equity, withdrawTreasuryFee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        assertEq(strategyFee, expectedStrategyFee);
        assertEq(treasuryFee, expectedTreasuryFee);

        assertEq(equityForStrategyAfterFees, equity);
        assertEq(equityForSharesAfterFees, equity + expectedStrategyFee);
    }

    function test_computeEquityFees_SumOfFeesGreaterThanEquity() public {
        ExternalAction action = ExternalAction.Deposit;
        uint256 equity = 1 ether;
        uint256 depositTreasuryFee = 6000;
        uint256 depositStrategyFee = 5000;
        _setFees(depositTreasuryFee, depositStrategyFee, 0, 0);

        (uint256 equityForStrategyAfterFees, uint256 equityForSharesAfterFees, uint256 strategyFee, uint256 treasuryFee)
        = feeManager.exposed_computeEquityFees(strategy, equity, action);

        uint256 expectedTreasuryFee = Math.mulDiv(equity, depositTreasuryFee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        assertEq(treasuryFee, expectedTreasuryFee);

        uint256 expectedStrategyFee = equity - expectedTreasuryFee;
        assertEq(strategyFee, expectedStrategyFee);

        assertEq(equityForStrategyAfterFees, equity - expectedTreasuryFee);
        assertEq(equityForSharesAfterFees, equity - (expectedTreasuryFee + expectedStrategyFee));
    }

    function test_computeEquityFees_TreasuryNotSet() public {
        // Mocked values that don't matter for this test
        ExternalAction action = ExternalAction.Deposit;
        uint256 equity = 1 ether;
        uint256 depositTreasuryFee = 100;
        uint256 depositStrategyFee = 200;
        uint256 withdrawTreasuryFee = 300;
        uint256 withdrawStrategyFee = 400;
        _setFees(depositTreasuryFee, depositStrategyFee, withdrawTreasuryFee, withdrawStrategyFee);

        _setTreasury(feeManagerRole, address(0));

        (uint256 equityForStrategyAfterFees,,, uint256 treasuryFee) =
            feeManager.exposed_computeEquityFees(strategy, equity, action);
        assertEq(equityForStrategyAfterFees, equity);
        assertEq(treasuryFee, 0);
    }

    function testFuzz_computeEquityFees(
        uint128 equity,
        uint256 depositTreasuryFee,
        uint256 depositStrategyFee,
        uint256 withdrawTreasuryFee,
        uint256 withdrawStrategyFee
    ) public {
        ExternalAction action = ExternalAction.Deposit;
        depositTreasuryFee = bound(depositTreasuryFee, 0, feeManager.MAX_FEE());
        depositStrategyFee = bound(depositStrategyFee, 0, feeManager.MAX_FEE());
        withdrawTreasuryFee = bound(withdrawTreasuryFee, 0, feeManager.MAX_FEE());
        withdrawStrategyFee = bound(withdrawStrategyFee, 0, feeManager.MAX_FEE());
        _setFees(depositTreasuryFee, depositStrategyFee, withdrawTreasuryFee, withdrawStrategyFee);

        (uint256 equityForStrategyAfterFees, uint256 equityForSharesAfterFees, uint256 strategyFee, uint256 treasuryFee)
        = feeManager.exposed_computeEquityFees(strategy, equity, action);

        uint256 expectedTreasuryFee = Math.mulDiv(
            equity,
            action == ExternalAction.Deposit ? depositTreasuryFee : withdrawTreasuryFee,
            feeManager.MAX_FEE(),
            Math.Rounding.Ceil
        );
        assertEq(treasuryFee, expectedTreasuryFee);

        uint256 expectedStrategyFee = Math.mulDiv(
            equity,
            action == ExternalAction.Deposit ? depositStrategyFee : withdrawStrategyFee,
            feeManager.MAX_FEE(),
            Math.Rounding.Ceil
        );
        if (expectedStrategyFee + expectedTreasuryFee > equity) {
            expectedStrategyFee = equity - expectedTreasuryFee;
        }
        assertEq(strategyFee, expectedStrategyFee);

        uint256 expectedEquityForStrategyAfterFees =
            action == ExternalAction.Deposit ? equity - expectedTreasuryFee : equity;
        assertEq(equityForStrategyAfterFees, expectedEquityForStrategyAfterFees);

        uint256 expectedEquityForSharesAfterFees = action == ExternalAction.Deposit
            ? expectedEquityForStrategyAfterFees - expectedStrategyFee
            : expectedEquityForStrategyAfterFees + expectedStrategyFee;
        assertEq(equityForSharesAfterFees, expectedEquityForSharesAfterFees);

        assertLe(strategyFee + treasuryFee, equity);
        assertLe(expectedEquityForSharesAfterFees, equity);
        assertLe(expectedEquityForStrategyAfterFees, equity);
    }

    function _setFees(
        uint256 depositTreasuryFee,
        uint256 depositStrategyFee,
        uint256 withdrawTreasuryFee,
        uint256 withdrawStrategyFee
    ) internal {
        vm.startPrank(feeManagerRole);
        feeManager.setTreasuryActionFee(ExternalAction.Deposit, depositTreasuryFee);
        feeManager.setTreasuryActionFee(ExternalAction.Withdraw, withdrawTreasuryFee);
        feeManager.exposed_setStrategyActionFee(strategy, ExternalAction.Deposit, depositStrategyFee);
        feeManager.exposed_setStrategyActionFee(strategy, ExternalAction.Withdraw, withdrawStrategyFee);
        vm.stopPrank();
    }
}
