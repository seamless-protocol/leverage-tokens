// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ValidateTreasurySetTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateTreasurySet(address _treasury) public {
        vm.assume(_treasury != address(0));

        vm.prank(feeManagerRole);
        feeManager.setTreasury(_treasury);

        // Does not revert
        feeManager.exposed_validateTreasurySet();
    }

    function test_validateTreasurySet_RevertIf_TreasuryNotSet() public {
        vm.prank(feeManagerRole);
        feeManager.setTreasury(address(0));

        vm.expectRevert(IFeeManager.TreasuryNotSet.selector);
        feeManager.exposed_validateTreasurySet();
    }
}
