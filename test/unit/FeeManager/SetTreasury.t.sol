// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetTreasuryTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setTreasury(address treasury) public {
        vm.startPrank(feeManagerRole);
        feeManager.setTreasury(treasury);
        assertTrue(feeManager.getTreasury() == treasury);
    }

    function testFuzz_setTreasury_CallerIsNotFeeManagerRole(address caller, address treasury) public {
        vm.assume(caller != feeManagerRole);
        vm.startPrank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );
        feeManager.setTreasury(treasury);
    }
}
