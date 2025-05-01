// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract UpdateLastManagementFeeAccrualTimestampTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_updateLastManagementFeeAccrualTimestamp(uint120 timestamp) public {
        vm.warp(timestamp);

        feeManager.exposed_updateLastManagementFeeAccrualTimestamp(leverageToken);

        assertEq(feeManager.getLastManagementFeeAccrualTimestamp(leverageToken), timestamp);
    }
}
