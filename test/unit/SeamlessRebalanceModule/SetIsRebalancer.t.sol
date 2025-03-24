// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetIsRebalancerTest is SeamlessRebalanceModuleBaseTest {
    /// forge-config: default.fuzz.runs = 1
    function test_setIsRebalancer(address rebalancer, bool isRebalancer) public {
        vm.prank(defaultAdmin);
        rebalanceModule.setIsRebalancer(rebalancer, isRebalancer);
        assertEq(rebalanceModule.getIsRebalancer(rebalancer), isRebalancer);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setIsRebalancer_RevertIf_NotOwner(address rebalancer, bool isRebalancer, address notOwner)
        public
    {
        vm.assume(notOwner != defaultAdmin);
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));
        rebalanceModule.setIsRebalancer(rebalancer, isRebalancer);
    }
}
