// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";

contract CreateAuctionTest is DutchAuctionRebalancerBaseTest {
    function test_createAuction_UnderCollateralized() public {
        // Set higher min ratio for this test
        _setStrategyCollateralRatios(1.5e8, MAX_RATIO, TARGET_RATIO);

        // Set current ratio to be below min (under-collateralized)
        _setStrategyCollateralRatio(1.4e8);

        // Set block timestamp
        vm.warp(AUCTION_START_TIME);

        // Create auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionCreated(
            strategy,
            IDutchAuctionRebalancer.Auction({
                isOverCollateralized: false,
                initialPriceMultiplier: auctionRebalancer.initialPriceMultiplier(strategy),
                minPriceMultiplier: auctionRebalancer.minPriceMultiplier(strategy),
                startTimestamp: AUCTION_START_TIME,
                endTimestamp: AUCTION_START_TIME + auctionRebalancer.auctionDuration(strategy)
            })
        );
        vm.prank(owner);
        auctionRebalancer.createAuction(strategy);

        // Verify auction details
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertFalse(isOverCollateralized);
        assertEq(initialPriceMultiplier, auctionRebalancer.initialPriceMultiplier(strategy));
        assertEq(minPriceMultiplier, auctionRebalancer.minPriceMultiplier(strategy));
        assertEq(startTimestamp, AUCTION_START_TIME);
        assertEq(endTimestamp, AUCTION_START_TIME + auctionRebalancer.auctionDuration(strategy));
    }

    function test_createAuction_OverCollateralized() public {
        // Set current ratio to be above max (over-collateralized)
        _setStrategyCollateralRatio(3.1e8);

        // Set block timestamp
        vm.warp(AUCTION_START_TIME);

        // Create auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionCreated(
            strategy,
            IDutchAuctionRebalancer.Auction({
                isOverCollateralized: true,
                initialPriceMultiplier: auctionRebalancer.initialPriceMultiplier(strategy),
                minPriceMultiplier: auctionRebalancer.minPriceMultiplier(strategy),
                startTimestamp: AUCTION_START_TIME,
                endTimestamp: AUCTION_START_TIME + auctionRebalancer.auctionDuration(strategy)
            })
        );
        vm.prank(owner);
        auctionRebalancer.createAuction(strategy);

        // Verify auction details
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(strategy);

        assertTrue(isOverCollateralized);
        assertEq(initialPriceMultiplier, auctionRebalancer.initialPriceMultiplier(strategy));
        assertEq(minPriceMultiplier, auctionRebalancer.minPriceMultiplier(strategy));
        assertEq(startTimestamp, AUCTION_START_TIME);
        assertEq(endTimestamp, AUCTION_START_TIME + auctionRebalancer.auctionDuration(strategy));
    }

    function test_createAuction_RevertIf_StrategyNotEligible() public {
        // Set current ratio to be within bounds (not eligible)
        _setStrategyCollateralRatio(1.5e8);

        // Try to create auction
        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.StrategyNotEligibleForRebalance.selector);
        auctionRebalancer.createAuction(strategy);
    }

    function test_createAuction_RevertIf_AuctionStillValid() public {
        // Set current ratio to be above max (eligible)
        _setStrategyCollateralRatio(3.1e8);

        // Create first auction
        _createAuction();

        // Try to create another auction while first is still valid
        vm.warp(AUCTION_START_TIME + auctionRebalancer.auctionDuration(strategy) - 1);
        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.AuctionStillValid.selector);
        auctionRebalancer.createAuction(strategy);
    }
}
