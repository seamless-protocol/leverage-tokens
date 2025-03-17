// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";

// Internal imports
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract UpgradeToAndCallTest is LeverageManagerBaseTest {
    function test_upgradeToAndCall() public {
        address upgrader = makeAddr("upgrader");

        // Deploy new implementation
        LeverageManager newImplementation = new LeverageManager();

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.UPGRADER_ROLE(), upgrader);
        vm.stopPrank();

        // Expect the Upgraded event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IERC1967.Upgraded(address(newImplementation));

        // Upgrade
        vm.prank(upgrader);
        leverageManager.upgradeToAndCall(address(newImplementation), "");
    }
}
