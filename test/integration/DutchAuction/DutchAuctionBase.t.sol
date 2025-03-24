// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {RebalanceTest} from "test/integration/LeverageManager/Rebalance.t.sol";
import {DutchAuctionRebalancer} from "src/rebalance/DutchAuctionRebalancer.sol";
import {Auction, StrategyState} from "src/types/DataTypes.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";

contract DutchAuctionBase is RebalanceTest {
    function setUp() public override {
        super.setUp();

        DutchAuctionRebalancer(dutchAuctionModule).setInitialPriceMultiplier(ethLong2x, 1.2 * 1e18); // 1.2x from oracle price
        DutchAuctionRebalancer(dutchAuctionModule).setMinPriceMultiplier(ethLong2x, 0.9 * 1e18); // 0.9x from oracle price
        DutchAuctionRebalancer(dutchAuctionModule).setAuctionDuration(ethLong2x, 7 minutes);
    }

    function testFork_createAuction_OverCollateralized() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(isOverCollateralized, true);
        assertEq(initialPriceMultiplier, 1.2 * 1e18);
        assertEq(minPriceMultiplier, 0.9 * 1e18);
        assertEq(startTimestamp, block.timestamp);
        assertEq(endTimestamp, block.timestamp + 7 minutes);
    }

    function testFork_createAuction_UnderCollateralized() public {
        _prepareUnderCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(isOverCollateralized, false);
        assertEq(initialPriceMultiplier, 1.2 * 1e18);
        assertEq(minPriceMultiplier, 0.9 * 1e18);
        assertEq(startTimestamp, block.timestamp);
        assertEq(endTimestamp, block.timestamp + 7 minutes);
    }

    function testFork_createAuction_MinMulitplierIsNotRetroactivelyChanged() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        // Change min multiplier
        DutchAuctionRebalancer(dutchAuctionModule).setMinPriceMultiplier(ethLong2x, 0.8 * 1e18);

        (,, uint256 minPriceMultiplier,,) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);
        assertEq(minPriceMultiplier, 0.9 * 1e18);
    }

    function testFork_createAuction_DeletesPreviousInvalidAuction_IfTimePassed() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        // Change price multiplier
        DutchAuctionRebalancer(dutchAuctionModule).setMinPriceMultiplier(ethLong2x, 0.6 * 1e18);

        // Time passes
        vm.warp(block.timestamp + 7 minutes + 1);

        // Create auction again
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(startTimestamp, block.timestamp);
        assertEq(endTimestamp, block.timestamp + 7 minutes);
        assertEq(isOverCollateralized, true);
        assertEq(initialPriceMultiplier, 1.2 * 1e18);
        assertEq(minPriceMultiplier, 0.6 * 1e18);
    }

    function testFork_createAuction_RevertIf_NotEligibleForRebalanceNoMore() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        // Change ETH price 20% down
        _moveEthPrice(-20_00);

        // Create auction again
        vm.expectRevert(IDutchAuctionRebalancer.StrategyNotEligibleForRebalance.selector);
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);
    }

    function test_Fork_createAuction_DeletesPreviousInvalidAuctionIf_CollateralRatioDirectionChanged() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        // Move ETH price 40% down
        _moveEthPrice(-40_00);

        // Create auction again
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(startTimestamp, block.timestamp);
        assertEq(endTimestamp, block.timestamp + 7 minutes);
        assertEq(isOverCollateralized, false);
        assertEq(initialPriceMultiplier, 1.2 * 1e18);
        assertEq(minPriceMultiplier, 0.9 * 1e18);
    }

    function testFork_createAuction_RevertIf_StrategyNotEligibleForRebalance() public {
        uint256 equityToDeposit = 10 * 1e18;
        uint256 collateralToAdd = leverageManager.previewDeposit(ethLong2x, equityToDeposit).collateral;
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);

        vm.expectRevert(IDutchAuctionRebalancer.StrategyNotEligibleForRebalance.selector);
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);
    }

    function _prepareOverCollateralizedState() internal {
        // Deposit 10 WETH following target ratio
        uint256 equityToDeposit = 10 * 1e18;
        uint256 collateralToAdd = leverageManager.previewDeposit(ethLong2x, equityToDeposit).collateral;
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);

        _moveEthPrice(20_00); // 20% up price movement. Collateral ratio should be 2.4x
    }

    function _prepareUnderCollateralizedState() internal {
        // Deposit 10 WETH following target ratio
        uint256 equityToDeposit = 10 * 1e18;
        uint256 collateralToAdd = leverageManager.previewDeposit(ethLong2x, equityToDeposit).collateral;
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);

        _moveEthPrice(-20_00); // 20% down price movement. Collateral ratio should be 1.6x
    }
}
