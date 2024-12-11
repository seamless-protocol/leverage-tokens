// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyActionFee(address strategy, uint256 actionNum, uint256 fee) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.StrategyActionFeeSet(strategy, action, fee);

        _setStrategyActionFee(feeManagerRole, strategy, action, fee);

        assertEq(feeManager.getStrategyActionFee(strategy, action), fee);
    }

    function testFuzz_setStrategyActionFee_CallerIsNotFeeManagerRole(
        address caller,
        address strategy,
        uint256 actionNum,
        uint256 fee
    ) public {
        vm.assume(caller != feeManagerRole);
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );
        _setStrategyActionFee(caller, strategy, action, fee);
    }

    function testFuzz_setStrategyActionFee_RevertIfFeeTooHigh(address strategy, uint256 actionNum, uint256 fee)
        public
    {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, feeManager.MAX_FEE() + 1, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector));
        _setStrategyActionFee(feeManagerRole, strategy, action, fee);
    }
}
