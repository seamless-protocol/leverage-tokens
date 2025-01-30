// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {SwapperBaseTest} from "./SwapperBase.t.sol";
import {SwapperHarness} from "./harness/SwapperHarness.sol";

contract AuthorizeUpgradeTest is SwapperBaseTest {
    /// forge-config: default.fuzz.runs = 1
    function testFuzz_AuthorizeUpgrade(address caller, address newImplementation) public {
        SwapperHarness _swapper = SwapperHarness(address(swapper));
        vm.startPrank(defaultAdmin);
        _swapper.grantRole(_swapper.UPGRADER_ROLE(), caller);
        vm.stopPrank();

        // Expect not to revert
        vm.prank(caller);
        _swapper.exposed_authorizeUpgrade(newImplementation);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_AuthorizeUpgrade_RevertIf_CallerIsNotUpgrader(address caller, address newImplementation) public {
        SwapperHarness _swapper = SwapperHarness(address(swapper));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, _swapper.UPGRADER_ROLE()
            )
        );
        vm.prank(caller);
        _swapper.exposed_authorizeUpgrade(newImplementation);
    }
}
