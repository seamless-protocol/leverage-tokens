// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {Auction} from "src/types/DataTypes.sol";

contract CreateAuctionTest is DutchAuctionRebalancerBaseTest {
    function test_createAuction_UnderCollateralized() public {
        // Set higher min ratio for this test
        _mockLeverageTokenCollateralRatios(1.5e8, MAX_RATIO);

        // Set current ratio to be below min (under-collateralized)
        _setLeverageTokenCollateralRatio(1.4e8);

        // Set block timestamp
        vm.warp(AUCTION_START_TIME);

        // Create auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionCreated(
            leverageToken,
            Auction({
                isOverCollateralized: false,
                initialPriceMultiplier: auctionRebalancer.initialPriceMultiplier(leverageToken),
                minPriceMultiplier: auctionRebalancer.minPriceMultiplier(leverageToken),
                startTimestamp: AUCTION_START_TIME,
                endTimestamp: AUCTION_START_TIME + auctionRebalancer.auctionDuration(leverageToken)
            })
        );
        vm.prank(owner);
        auctionRebalancer.createAuction(leverageToken);

        // Verify auction details
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(leverageToken);

        assertFalse(isOverCollateralized);
        assertEq(initialPriceMultiplier, auctionRebalancer.initialPriceMultiplier(leverageToken));
        assertEq(minPriceMultiplier, auctionRebalancer.minPriceMultiplier(leverageToken));
        assertEq(startTimestamp, AUCTION_START_TIME);
        assertEq(endTimestamp, AUCTION_START_TIME + auctionRebalancer.auctionDuration(leverageToken));
    }

    function test_createAuction_OverCollateralized() public {
        // Set current ratio to be above max (over-collateralized)
        _setLeverageTokenCollateralRatio(3.1e8);

        // Set block timestamp
        vm.warp(AUCTION_START_TIME);

        // Create auction
        vm.expectEmit(true, true, true, true);
        emit IDutchAuctionRebalancer.AuctionCreated(
            leverageToken,
            Auction({
                isOverCollateralized: true,
                initialPriceMultiplier: auctionRebalancer.initialPriceMultiplier(leverageToken),
                minPriceMultiplier: auctionRebalancer.minPriceMultiplier(leverageToken),
                startTimestamp: AUCTION_START_TIME,
                endTimestamp: AUCTION_START_TIME + auctionRebalancer.auctionDuration(leverageToken)
            })
        );
        vm.prank(owner);
        auctionRebalancer.createAuction(leverageToken);

        // Verify auction details
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = auctionRebalancer.auctions(leverageToken);

        assertTrue(isOverCollateralized);
        assertEq(initialPriceMultiplier, auctionRebalancer.initialPriceMultiplier(leverageToken));
        assertEq(minPriceMultiplier, auctionRebalancer.minPriceMultiplier(leverageToken));
        assertEq(startTimestamp, AUCTION_START_TIME);
        assertEq(endTimestamp, AUCTION_START_TIME + auctionRebalancer.auctionDuration(leverageToken));
    }

    function test_createAuction_RevertIf_LeverageTokenNotEligible() public {
        // Set current ratio to be within bounds (not eligible)
        _setLeverageTokenCollateralRatio(1.5e8);

        // Try to create auction
        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.LeverageTokenNotEligibleForRebalance.selector);
        auctionRebalancer.createAuction(leverageToken);
    }

    function test_createAuction_RevertIf_AuctionStillValid() public {
        // Set current ratio to be above max (eligible)
        _setLeverageTokenCollateralRatio(3.1e8);

        // Create first auction
        _createAuction();

        // Try to create another auction while first is still valid
        vm.warp(AUCTION_START_TIME + auctionRebalancer.auctionDuration(leverageToken) - 1);
        vm.prank(owner);
        vm.expectRevert(IDutchAuctionRebalancer.AuctionStillValid.selector);
        auctionRebalancer.createAuction(leverageToken);
    }
}
