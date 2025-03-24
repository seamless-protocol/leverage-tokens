// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Internal imports
import {SeamlessRebalanceModule} from "src/rebalance/SeamlessRebalanceModule.sol";
import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";

contract UpgradeToAndCallTest is SeamlessRebalanceModuleBaseTest {
    function test_upgradeToAndCall() public {
        // Deploy new implementation
        SeamlessRebalanceModule newImplementation = new SeamlessRebalanceModule();

        // Expect the Upgraded event to be emitted
        vm.expectEmit(true, true, true, true);
        emit IERC1967.Upgraded(address(newImplementation));

        // Upgrade
        vm.prank(defaultAdmin);
        rebalanceModule.upgradeToAndCall(address(newImplementation), "");
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_upgradeToAndCall_RevertIf_NonUpgraderUpgrades(address nonUpgrader) public {
        vm.assume(nonUpgrader != defaultAdmin);

        SeamlessRebalanceModule newImplementation = new SeamlessRebalanceModule();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonUpgrader));
        vm.prank(nonUpgrader);
        rebalanceModule.upgradeToAndCall(address(newImplementation), "");
    }
}
