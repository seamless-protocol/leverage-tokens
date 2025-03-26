// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerTest} from "./LeverageManager.t.sol";

contract SetLeverageTokenFactoryTest is LeverageManagerTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setLeverageTokenFactory(address factory) public {
        vm.prank(defaultAdmin);
        leverageManager.setLeverageTokenFactory(factory);

        assertEq(address(leverageManager.getLeverageTokenFactory()), address(factory));
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setLeverageTokenFactory_RevertIf_CallerIsNotDefaultAdmin(address caller, address factory)
        public
    {
        vm.assume(caller != defaultAdmin);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(caller);
        leverageManager.setLeverageTokenFactory(factory);
    }
}
