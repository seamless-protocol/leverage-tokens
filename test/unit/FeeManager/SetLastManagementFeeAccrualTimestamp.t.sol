// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {FeeManagerTest} from "test/unit/FeeManager/FeeManager.t.sol";

contract SetLastManagementFeeAccrualTimestampTest is FeeManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setLastManagementFeeAccrualTimestamp(ILeverageToken _leverageToken, uint120 timestamp) public {
        vm.warp(timestamp);
        feeManager.exposed_setLastManagementFeeAccrualTimestamp(_leverageToken);
        assertEq(feeManager.getLastManagementFeeAccrualTimestamp(_leverageToken), timestamp);
    }
}
