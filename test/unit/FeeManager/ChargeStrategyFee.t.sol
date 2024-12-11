// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_chargeStrategyFee(address strategy, uint256 amount, uint256 actionNum, uint256 fee) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        uint256 expectedAmountAfterFee = Math.mulDiv(amount, feeManager.MAX_FEE() - fee, feeManager.MAX_FEE());

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeeCharged(strategy, action, amount, amount - expectedAmountAfterFee);

        uint256 amountAfterFee = feeManager.chargeStrategyFee(strategy, amount, action);

        assertEq(amountAfterFee, expectedAmountAfterFee);
    }
}
