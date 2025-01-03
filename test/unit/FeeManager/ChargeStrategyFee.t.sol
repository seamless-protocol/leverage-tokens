// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_chargeStrategyFee_FeeRoundedUp() public {
        address strategy = makeAddr("strategy");
        uint256 amount = 1;
        uint256 fee = 1;

        for (uint256 i = 0; i < uint256(type(IFeeManager.Action).max) + 1; i++) {
            _setStrategyActionFee(feeManagerRole, strategy, IFeeManager.Action(i), fee);

            uint256 amountAfterFee = feeManager.exposed_chargeStrategyFee(strategy, amount, IFeeManager.Action.Deposit);

            assertEq(amountAfterFee, 0);
        }
    }

    function testFuzz_chargeStrategyFee(address strategy, uint256 amount, uint256 actionNum, uint256 fee) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        uint256 expectedAmountAfterFee = Math.mulDiv(amount, feeManager.MAX_FEE() - fee, feeManager.MAX_FEE());

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeeCharged(strategy, action, amount, amount - expectedAmountAfterFee);

        uint256 amountAfterFee = feeManager.exposed_chargeStrategyFee(strategy, amount, action);

        assertEq(amountAfterFee, expectedAmountAfterFee);
    }
}
