// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetStrategyActionFeeTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee(uint256 strategyId, uint256 actionNum, uint256 fee) public {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, 0, feeManager.MAX_FEE());

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.StrategyActionFeeSet(strategyId, action, fee);

        _setStrategyActionFee(feeManagerRole, strategyId, action, fee);

        assertEq(feeManager.getStrategyActionFee(strategyId, action), fee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee_CallerIsNotFeeManagerRole(
        address caller,
        uint256 strategyId,
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
        _setStrategyActionFee(caller, strategyId, action, fee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyActionFee_RevertIfFeeTooHigh(uint256 strategyId, uint256 actionNum, uint256 fee)
        public
    {
        IFeeManager.Action action = IFeeManager.Action(bound(actionNum, 0, 2));
        fee = bound(fee, feeManager.MAX_FEE() + 1, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector, fee, feeManager.MAX_FEE()));
        _setStrategyActionFee(feeManagerRole, strategyId, action, fee);
    }
}
