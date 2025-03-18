// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerTest} from "./DutchAuctionRebalancer.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SetInitialPricePremiumTest is DutchAuctionRebalancerTest {
    function test_setInitialPriceMultiplier() public {
        uint256 newMultiplier = 11000; // 110%

        vm.prank(owner);
        auctionRebalancer.setInitialPriceMultiplier(strategy, newMultiplier);

        assertEq(auctionRebalancer.initialPriceMultiplier(strategy), newMultiplier);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setInitialPriceMultiplier(uint256 newMultiplier) public {
        vm.prank(owner);
        auctionRebalancer.setInitialPriceMultiplier(strategy, newMultiplier);

        assertEq(auctionRebalancer.initialPriceMultiplier(strategy), newMultiplier);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setInitialPriceMultiplier_RevertIf_NotOwner(uint256 newMultiplier, address notOwner) public {
        vm.assume(notOwner != owner);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        auctionRebalancer.setInitialPriceMultiplier(strategy, newMultiplier);
    }
}
