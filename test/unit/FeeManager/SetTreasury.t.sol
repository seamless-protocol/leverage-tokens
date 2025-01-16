// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";

contract SetTreasuryTest is FeeManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setTreasury(address treasury) public {
        vm.startPrank(feeManagerRole);

        vm.expectEmit(true, true, true, true);
        emit IFeeManager.TreasurySet(treasury);

        feeManager.setTreasury(treasury);
        assertEq(feeManager.getTreasury(), treasury);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setTreasury_CallerIsNotFeeManagerRole(address caller, address treasury) public {
        vm.assume(caller != feeManagerRole);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, feeManager.FEE_MANAGER_ROLE()
            )
        );

        vm.prank(caller);
        feeManager.setTreasury(treasury);
    }
}
