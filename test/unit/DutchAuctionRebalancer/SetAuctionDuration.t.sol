// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SetAuctionDurationTest is DutchAuctionRebalancerBaseTest {
    function test_setAuctionDuration() public {
        uint256 newDuration = 1 hours;

        vm.prank(owner);
        auctionRebalancer.setAuctionDuration(strategy, newDuration);

        assertEq(auctionRebalancer.auctionDuration(strategy), newDuration);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setAuctionDuration(uint256 newDuration) public {
        vm.assume(newDuration > 0);

        vm.prank(owner);
        auctionRebalancer.setAuctionDuration(strategy, newDuration);

        assertEq(auctionRebalancer.auctionDuration(strategy), newDuration);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setAuctionDuration_RevertIf_NotOwner(uint256 newDuration, address notOwner) public {
        vm.assume(notOwner != owner);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        auctionRebalancer.setAuctionDuration(strategy, newDuration);
    }

    function test_setAuctionDuration_RevertIf_ZeroDuration() public {
        uint256 newDuration = 0;

        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.InvalidAuctionDuration.selector);
        auctionRebalancer.setAuctionDuration(strategy, newDuration);
    }
}
