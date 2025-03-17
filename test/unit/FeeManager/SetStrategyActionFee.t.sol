// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ExternalAction} from "src/types/DataTypes.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";
import {FeeManager} from "src/FeeManager.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee(uint256 actionNum, uint256 fee) public {
        ExternalAction action = ExternalAction(actionNum % 2);
        fee = bound(fee, 0, feeManager.MAX_FEE());

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.StrategyActionFeeSet(action, fee);

        _setStrategyActionFee(feeManagerRole, action, fee);

        assertEq(feeManager.getStrategyActionFee(action), fee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee_CallerIsNotFeeManagerRole(address caller, uint256 actionNum, uint256 fee)
        public
    {
        vm.assume(caller != feeManagerRole);
        ExternalAction action = ExternalAction(actionNum % 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );
        _setStrategyActionFee(caller, action, fee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee_RevertIfFeeTooHigh(uint256 actionNum, uint256 fee) public {
        ExternalAction action = ExternalAction(actionNum % 2);
        fee = bound(fee, feeManager.MAX_FEE() + 1, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector, fee, feeManager.MAX_FEE()));
        _setStrategyActionFee(feeManagerRole, action, fee);
    }
}
