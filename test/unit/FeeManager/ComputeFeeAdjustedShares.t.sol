// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {console} from "forge-std/console.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_computeFeeAdjustedShares_FeeRoundedUp() public {
        IStrategy strategy = IStrategy(makeAddr("strategy"));
        uint256 amount = 1;
        uint256 fee = 1;

        _setStrategyActionFee(feeManagerRole, strategy, ExternalAction.Deposit, fee);
        _setStrategyActionFee(feeManagerRole, strategy, ExternalAction.Withdraw, fee);

        // For deposit shares minted are going down
        (uint256 amountAfterFee, uint256 feeAmount) =
            feeManager.exposed_computeFeeAdjustedShares(strategy, amount, ExternalAction.Deposit);

        assertEq(amountAfterFee, 0);
        assertEq(feeAmount, 1);

        // For withdraw shares burned are going up
        (amountAfterFee, feeAmount) =
            feeManager.exposed_computeFeeAdjustedShares(strategy, amount, ExternalAction.Withdraw);

        assertEq(amountAfterFee, 2);
        assertEq(feeAmount, 1);
    }

    function testFuzz_computeFeeAdjustedShares(IStrategy strategy, uint128 amount, uint256 actionNum, uint256 fee)
        public
    {
        ExternalAction action = ExternalAction(actionNum % 2);
        fee = bound(fee, 0, feeManager.MAX_FEE());

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        uint256 expectedFeeAmount = Math.mulDiv(amount, fee, feeManager.MAX_FEE(), Math.Rounding.Ceil);
        uint256 expectedAmountAfterFee =
            action == ExternalAction.Deposit ? amount - expectedFeeAmount : amount + expectedFeeAmount;

        (uint256 amountAfterFee, uint256 feeAmount) =
            feeManager.exposed_computeFeeAdjustedShares(strategy, amount, action);

        assertEq(amountAfterFee, expectedAmountAfterFee);
        assertEq(feeAmount, expectedFeeAmount);
    }
}
