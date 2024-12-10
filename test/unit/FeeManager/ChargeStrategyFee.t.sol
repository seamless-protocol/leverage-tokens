// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerStorage as Storage} from "src/storage/FeeManagerStorage.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    using SafeCast for uint256;

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_chargeStrategyFee(address strategy, uint256 amount, uint256 actionNum, uint256 fee) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);
        uint256 amountAfterFee = feeManager.chargeStrategyFee(strategy, amount, action);

        uint256 expectedAmountAfterFee = Math.mulDiv(amount, feeManager.MAX_FEE() - fee, feeManager.MAX_FEE());
        assertEq(amountAfterFee, expectedAmountAfterFee);
    }
}
