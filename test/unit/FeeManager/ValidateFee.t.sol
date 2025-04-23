// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract ValidateFeeTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateFee(uint256 fee) public view {
        fee = bound(fee, 0, MAX_FEE);

        // Does not revert
        feeManager.exposed_validateFee(fee);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_validateFee_RevertIf_FeeTooHigh(uint256 fee) public {
        fee = bound(fee, MAX_FEE + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeeTooHigh.selector, fee, MAX_FEE));
        feeManager.exposed_validateFee(fee);
    }
}
