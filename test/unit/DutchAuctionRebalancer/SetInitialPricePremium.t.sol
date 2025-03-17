// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerTest} from "./DutchAuctionRebalancer.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SetInitialPricePremiumTest is DutchAuctionRebalancerTest {
    function test_setInitialPricePremium() public {
        uint256 newPremiumBps = 1000; // 10%

        vm.prank(owner);
        auctionRebalancer.setInitialPricePremium(strategy, newPremiumBps);

        assertEq(auctionRebalancer.initialPricePremiumBps(strategy), newPremiumBps);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setInitialPricePremium(uint256 newPremiumBps) public {
        vm.assume(newPremiumBps <= BPS_DENOMINATOR);

        vm.prank(owner);
        auctionRebalancer.setInitialPricePremium(strategy, newPremiumBps);

        assertEq(auctionRebalancer.initialPricePremiumBps(strategy), newPremiumBps);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setInitialPricePremium_RevertIf_NotOwner(uint256 newPremiumBps, address notOwner) public {
        vm.assume(notOwner != owner);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        auctionRebalancer.setInitialPricePremium(strategy, newPremiumBps);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setInitialPricePremium_RevertIf_PremiumTooHigh(uint256 newPremiumBps) public {
        vm.assume(newPremiumBps > BPS_DENOMINATOR);

        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.InvalidPricePremium.selector);
        auctionRebalancer.setInitialPricePremium(strategy, newPremiumBps);
    }
}
