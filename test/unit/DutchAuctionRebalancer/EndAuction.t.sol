// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";

contract EndAuctionTest is DutchAuctionRebalancerBaseTest {
    function test_endAuction_WhenExpired() public {
        // Create an auction that will be expired
        _setStrategyCollateralRatio(3.1e8); // Over-collateralized
        _createAuction();

        // Warp to after auction end time
        vm.warp(AUCTION_START_TIME + DEFAULT_DURATION + 1);

        // End auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionEnded(strategy);
        auctionRebalancer.endAuction(strategy);

        // Verify auction was deleted
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(initialPriceMultiplier, 0);
        assertEq(minPriceMultiplier, 0);
        assertFalse(isOverCollateralized);
    }

    function test_endAuction_WhenStrategyNoLongerEligible() public {
        // Create an auction when over-collateralized
        _setStrategyCollateralRatio(3.1e8);
        _createAuction();

        // Change strategy state to be within bounds (no longer eligible)
        _setStrategyCollateralRatio(2e8);

        // End auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionEnded(strategy);
        auctionRebalancer.endAuction(strategy);

        // Verify auction was deleted
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(initialPriceMultiplier, 0);
        assertEq(minPriceMultiplier, 0);
        assertFalse(isOverCollateralized);
    }

    function test_endAuction_WhenCollateralRatioDirectionChanged() public {
        // Create an auction when over-collateralized
        _setStrategyCollateralRatio(3.1e8);
        _createAuction();

        // Change strategy state to be under-collateralized
        _setStrategyCollateralRatio(0.9e8);

        // End auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionEnded(strategy);
        auctionRebalancer.endAuction(strategy);

        // Verify auction was deleted
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(initialPriceMultiplier, 0);
        assertEq(minPriceMultiplier, 0);
        assertFalse(isOverCollateralized);
    }

    function test_endAuction_RevertIf_AuctionStillValid() public {
        // Create an auction
        _setStrategyCollateralRatio(3.1e8);
        _createAuction();

        // Try to end auction while it's still valid
        vm.warp(AUCTION_START_TIME + DEFAULT_DURATION - 1);
        vm.expectRevert(IDutchAuctionRebalancer.AuctionStillValid.selector);
        auctionRebalancer.endAuction(strategy);
    }

    function testFuzz_endAuction_WhenExpired(uint256 timeAfterExpiry) public {
        // Create an auction
        _setStrategyCollateralRatio(3.1e8);
        _createAuction();

        // Warp to some time after auction expiry
        timeAfterExpiry = bound(timeAfterExpiry, 1, 365 days);
        vm.warp(AUCTION_START_TIME + DEFAULT_DURATION + timeAfterExpiry);

        // End auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionEnded(strategy);
        auctionRebalancer.endAuction(strategy);

        // Verify auction was deleted
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(initialPriceMultiplier, 0);
        assertEq(minPriceMultiplier, 0);
        assertFalse(isOverCollateralized);
    }
}
