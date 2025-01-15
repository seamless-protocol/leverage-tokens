// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
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
        assertEq(leverageManager.getIsLendingAdapterUsed(adapter), true);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyLendingAdapter_ProperlyReplaceOldAdapter(
        address strategy,
        address adapter1,
        address adapter2
    ) public {
        vm.assume(adapter1 != adapter2);
        vm.startPrank(manager);

        leverageManager.setStrategyLendingAdapter(strategy, adapter1);
        assertEq(address(leverageManager.getStrategyLendingAdapter(strategy)), address(adapter1));
        assertEq(leverageManager.getIsLendingAdapterUsed(adapter1), true);

        leverageManager.setStrategyLendingAdapter(strategy, adapter2);
        assertEq(address(leverageManager.getStrategyLendingAdapter(strategy)), address(adapter2));
        assertEq(leverageManager.getIsLendingAdapterUsed(adapter1), false);
        assertEq(leverageManager.getIsLendingAdapterUsed(adapter2), true);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyLendingAdapter_RevertIf_DuplicateAdapter(address strategy, address adapter) public {
        vm.startPrank(manager);
        leverageManager.setStrategyLendingAdapter(strategy, adapter);

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.LendingAdapterAlreadyInUse.selector, adapter));
        leverageManager.setStrategyLendingAdapter(strategy, adapter);
        vm.stopPrank();
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
