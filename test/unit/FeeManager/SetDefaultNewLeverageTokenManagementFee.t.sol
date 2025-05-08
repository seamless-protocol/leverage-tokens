// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";
import {FeeManager} from "src/FeeManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";

contract SetDefaultNewLeverageTokenManagementFeeTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setDefaultNewLeverageTokenManagementFee(uint256 managementFee) public {
        managementFee = bound(managementFee, 0, MAX_FEE);

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.DefaultNewLeverageTokenManagementFeeSet(managementFee);
        _setDefaultNewLeverageTokenManagementFee(feeManagerRole, managementFee);

        assertEq(feeManager.getDefaultNewLeverageTokenManagementFee(), managementFee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setDefaultNewLeverageTokenManagementFee_RevertIf_FeeTooHigh(uint256 managementFee) public {
        managementFee = bound(managementFee, MAX_FEE + 1, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector, managementFee, MAX_FEE));
        _setDefaultNewLeverageTokenManagementFee(feeManagerRole, managementFee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setDefaultNewLeverageTokenManagementFee_RevertIf_CallerIsNotFeeManagerRole(
        address caller,
        uint256 managementFee
    ) public {
        vm.assume(caller != feeManagerRole);

        managementFee = bound(managementFee, 0, MAX_FEE);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );
        _setDefaultNewLeverageTokenManagementFee(caller, managementFee);
    }
}
