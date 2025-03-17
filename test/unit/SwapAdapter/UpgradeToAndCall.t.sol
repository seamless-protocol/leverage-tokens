// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";

// Internal imports
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {SwapAdapterBaseTest} from "./SwapAdapterBase.t.sol";

contract UpgradeToAndCallTest is SwapAdapterBaseTest {
    function test_upgradeToAndCall() public {
        address upgrader = makeAddr("upgrader");

        // Deploy new implementation
        SwapAdapter newImplementation = new SwapAdapter();

        vm.startPrank(defaultAdmin);
        swapAdapter.grantRole(swapAdapter.UPGRADER_ROLE(), upgrader);
        vm.stopPrank();

        // Expect the Upgraded event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IERC1967.Upgraded(address(newImplementation));

        // Upgrade
        vm.prank(upgrader);
        swapAdapter.upgradeToAndCall(address(newImplementation), "");
    }
}
