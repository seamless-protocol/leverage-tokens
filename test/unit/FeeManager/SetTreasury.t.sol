// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetTreasuryTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setTreasury(address treasury) public {
        vm.startPrank(feeManagerRole);

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.TreasurySet(treasury);

        feeManager.setTreasury(treasury);
        assertEq(feeManager.getTreasury(), treasury);
    }

    function test_setTreasury_CallerIsNotFeeManagerRole() public {
        address caller = makeAddr("caller");
        address treasury = makeAddr("treasury");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );

        vm.prank(caller);
        feeManager.setTreasury(treasury);
    }
}
