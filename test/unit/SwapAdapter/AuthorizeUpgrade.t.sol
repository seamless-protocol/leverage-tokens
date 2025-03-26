// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterTest} from "./SwapAdapter.t.sol";

contract AuthorizeUpgradeTest is SwapAdapterTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_AuthorizeUpgrade(address caller, address newImplementation) public {
        vm.startPrank(defaultAdmin);
        swapAdapter.grantRole(swapAdapter.UPGRADER_ROLE(), caller);
        vm.stopPrank();

        // Expect not to revert
        vm.prank(caller);
        swapAdapter.exposed_authorizeUpgrade(newImplementation);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_AuthorizeUpgrade_RevertIf_CallerIsNotUpgrader(address caller, address newImplementation) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, swapAdapter.UPGRADER_ROLE()
            )
        );
        vm.prank(caller);
        swapAdapter.exposed_authorizeUpgrade(newImplementation);
    }
}
