// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";

contract AuthorizeUpgradeTest is SeamlessRebalanceModuleBaseTest {
    function test_authorizeUpgrade_RevertIf_NotOwner(address caller, address newImplementation) public {
        vm.assume(caller != defaultAdmin);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        rebalanceModule.exposed_authorizeUpgrade(newImplementation);
    }

    function test_authorizeUpgrade(address newImplementation) public {
        vm.prank(defaultAdmin);
        rebalanceModule.exposed_authorizeUpgrade(newImplementation);
    }
}
