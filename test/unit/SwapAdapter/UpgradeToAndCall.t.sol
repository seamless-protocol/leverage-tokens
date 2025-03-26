// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterTest} from "./SwapAdapter.t.sol";

contract UpgradeToAndCallTest is SwapAdapterTest {
    address public upgrader = makeAddr("upgrader");

    function setUp() public override {
        super.setUp();

        vm.startPrank(defaultAdmin);
        swapAdapter.grantRole(swapAdapter.UPGRADER_ROLE(), upgrader);
        vm.stopPrank();
    }

    function test_upgradeToAndCall() public {
        // Deploy new implementation
        SwapAdapter newImplementation = new SwapAdapter();

        // Expect the Upgraded event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IERC1967.Upgraded(address(newImplementation));

        // Upgrade
        vm.prank(upgrader);
        swapAdapter.upgradeToAndCall(address(newImplementation), "");
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_upgradeToAndCall_RevertIf_NonUpgraderUpgrades(address nonUpgrader) public {
        vm.assume(nonUpgrader != upgrader);

        SwapAdapter newImplementation = new SwapAdapter();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonUpgrader, swapAdapter.UPGRADER_ROLE()
            )
        );
        vm.prank(nonUpgrader);
        swapAdapter.upgradeToAndCall(address(newImplementation), "");
    }
}
