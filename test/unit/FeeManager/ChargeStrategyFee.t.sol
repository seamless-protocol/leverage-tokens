// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_computeFeeAdjustedShares_FeeRoundedUp() public {
        IStrategy strategy = IStrategy(makeAddr("strategy"));
        uint256 amount = 1;
        uint256 fee = 1;

        for (uint256 i = 0; i < uint256(type(IFeeManager.Action).max) + 1; i++) {
            _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action(i), fee);

            uint256 amountAfterFee =
                feeManager.exposed_computeFeeAdjustedShares(strategy, amount, IFeeManager.Action.Deposit);

            assertEq(amountAfterFee, 0);
        }
    }

    function testFuzz_computeFeeAdjustedShares(IStrategy strategy, uint256 amount, uint256 actionNum, uint256 fee)
        public
    {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        uint256 expectedAmountAfterFee = Math.mulDiv(amount, feeManager.MAX_FEE() - fee, feeManager.MAX_FEE());

        uint256 amountAfterFee = feeManager.exposed_computeFeeAdjustedShares(strategy, amount, action);

        assertEq(amountAfterFee, expectedAmountAfterFee);
    }

    function test_computeSharesBeforeFeeAdjustment_SharesRoundedDown() public {
        IStrategy strategy = IStrategy(makeAddr("strategy"));
        uint256 amountAfterFee = 1;
        uint256 fee = 1;

        for (uint256 i = 0; i < uint256(type(IFeeManager.Action).max) + 1; i++) {
            _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action(i), fee);

            uint256 sharesBeforeFeeAdjustment =
                feeManager.exposed_computeSharesBeforeFeeAdjustment(strategy, amountAfterFee, IFeeManager.Action(i));
            assertEq(sharesBeforeFeeAdjustment, 1);
        }
    }

    function testFuzz_computeSharesBeforeFeeAdjustment(
        IStrategy strategy,
        uint256 amountAfterFee,
        uint256 actionNum,
        uint256 fee
    ) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        amountAfterFee = bound(amountAfterFee, 0, type(uint256).max / feeManager.MAX_FEE());
        fee = bound(fee, 0, feeManager.MAX_FEE() - 1);

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        uint256 expectedSharesBeforeFeeAdjustment =
            Math.mulDiv(amountAfterFee, feeManager.MAX_FEE(), feeManager.MAX_FEE() - fee, Math.Rounding.Floor);

        uint256 sharesBeforeFeeAdjustment =
            feeManager.exposed_computeSharesBeforeFeeAdjustment(strategy, amountAfterFee, action);

        assertEq(sharesBeforeFeeAdjustment, expectedSharesBeforeFeeAdjustment);
    }
}
