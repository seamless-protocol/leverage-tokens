// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract SetStrategyLendingAdapterTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyLendingAdapter(address strategy, address adapter) public {
        vm.prank(manager);
        leverageManager.setStrategyLendingAdapter(strategy, adapter);

        assertEq(address(leverageManager.getStrategyLendingAdapter(strategy)), address(adapter));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyLendingAdapter_RevertIf_CallerIsNotManager(
        address caller,
        address strategy,
        address adapter
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        vm.prank(caller);
        leverageManager.setStrategyLendingAdapter(strategy, adapter);
    }
}
