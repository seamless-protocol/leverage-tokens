// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract setStrategyCollateralCapTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCollateralCap(uint256 cap) public {
        _setStrategyCollateralCap(manager, cap);
        assertEq(leverageManager.getStrategyCollateralCap(strategyId), cap);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyCollateralCap_RevertIf_CallerIsNotManager(address caller, uint256 cap) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCollateralCap(caller, cap);
    }
}
