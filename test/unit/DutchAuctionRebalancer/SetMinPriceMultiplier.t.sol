// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerTest} from "./DutchAuctionRebalancer.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SetMinPriceMultiplierTest is DutchAuctionRebalancerTest {
    function test_setMinPriceMultiplier() public {
        uint256 newMultiplier = 11000; // 110%

        vm.prank(owner);
        auctionRebalancer.setMinPriceMultiplier(strategy, newMultiplier);

        assertEq(auctionRebalancer.minPriceMultiplier(strategy), newMultiplier);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setMinPriceMultiplier(uint256 newMultiplier) public {
        vm.assume(newMultiplier < DEFAULT_INITIAL_PRICE_MULTIPLIER);

        vm.prank(owner);
        auctionRebalancer.setMinPriceMultiplier(strategy, newMultiplier);

        assertEq(auctionRebalancer.minPriceMultiplier(strategy), newMultiplier);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setMinPriceMultiplier_RevertIf_NotOwner(uint256 newMultiplier, address notOwner) public {
        vm.assume(notOwner != owner);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        auctionRebalancer.setMinPriceMultiplier(strategy, newMultiplier);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setMinPriceMultiplier_RevertIf_MinPriceMultiplierTooHigh(
        uint256 initialPriceMultiplier,
        uint256 minMultiplier
    ) public {
        vm.assume(minMultiplier > initialPriceMultiplier);
        vm.assume(initialPriceMultiplier >= DEFAULT_MIN_PRICE_MULTIPLIER);

        vm.startPrank(owner);
        auctionRebalancer.setInitialPriceMultiplier(strategy, initialPriceMultiplier);

        vm.expectRevert(IDutchAuctionRebalancer.MinPriceMultiplierTooHigh.selector);
        auctionRebalancer.setMinPriceMultiplier(strategy, minMultiplier);

        vm.stopPrank();
    }
}
