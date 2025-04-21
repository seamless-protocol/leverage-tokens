// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";
import {FeeManager} from "src/FeeManager.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";

contract SetManagementFeeTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setManagementFee(uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, 0, feeManager.MAX_FEE()));

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.ManagementFeeSet(managementFee);
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);

        assertEq(feeManager.getManagementFee(), managementFee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setManagementFee_RevertIf_FeeTooHigh(uint128 managementFee) public {
        managementFee = uint128(bound(managementFee, feeManager.MAX_FEE() + 1, type(uint128).max));

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector, managementFee, feeManager.MAX_FEE()));
        vm.prank(feeManagerRole);
        feeManager.setManagementFee(managementFee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setManagementFee_RevertIf_CallerIsNotFeeManagerRole(address caller) public {
        vm.assume(caller != feeManagerRole);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );
        vm.prank(caller);
        feeManager.setManagementFee(0);
    }

    function test_setManagementFee_RevertIf_TreasuryNotSet() public {
        vm.prank(feeManagerRole);
        feeManager.setTreasury(address(0));

        vm.prank(feeManagerRole);
        vm.expectRevert(abi.encodeWithSelector(IFeeManager.TreasuryNotSet.selector));
        feeManager.setManagementFee(0.1e4);
    }
}
