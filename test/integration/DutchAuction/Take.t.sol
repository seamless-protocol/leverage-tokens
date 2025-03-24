// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {DutchAuctionBase} from "./DutchAuctionBase.t.sol";
import {DutchAuctionRebalancer} from "src/rebalance/DutchAuctionRebalancer.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";

contract Take is DutchAuctionBase {
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function testFork_take_OverCollateralized() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        StrategyState memory stateBefore = leverageManager.getStrategyState(ethLong2x);

        // Initial price is 102% or oracle. Highly unprofitable but is possible to be taken
        uint256 amountInAlice = _take_OverCollateralized(alice, 2_000 * 1e6);

        // Some time passes and Bob takes for better price
        vm.warp(block.timestamp + 2 minutes);
        uint256 amountInBob = _take_OverCollateralized(bob, 2_000 * 1e6);

        // Some more time passes and Charlie takes it for even better price

        vm.warp(block.timestamp + 4 minutes);
        uint256 amountInCharlie = _take_OverCollateralized(charlie, 2_000 * 1e6);

        StrategyState memory stateAfter = leverageManager.getStrategyState(ethLong2x);

        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio);

        // 1% is max loss because 99% is min auction multiplier
        uint256 maxLoss = stateBefore.equity / 100;
        assertGe(stateAfter.equity, stateBefore.equity - maxLoss);

        // Check if user received correct amount of debt
        assertEq(USDC.balanceOf(alice), 2_000 * 1e6);
        assertEq(USDC.balanceOf(bob), 2_000 * 1e6);
        assertEq(USDC.balanceOf(charlie), 2_000 * 1e6);

        // Auction should automatically be removed because strategy is back into healthy state
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(isOverCollateralized, false);
        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(minPriceMultiplier, 0);
        assertEq(initialPriceMultiplier, 0);

        assertLe(amountInBob, amountInAlice);
        assertLe(amountInCharlie, amountInBob);
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_take_UnderCollateralized() public {
        _prepareUnderCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        StrategyState memory stateBefore = leverageManager.getStrategyState(ethLong2x);

        // Alice takes for big price
        uint256 amountInAlice = _take_UnderCollateralized(alice, 1e18);

        // Some time passes and Bob takes for better price
        vm.warp(block.timestamp + 2 minutes);
        uint256 amountInBob = _take_UnderCollateralized(bob, 1e18);

        // Some more time passes and Charlie takes it for even better price
        vm.warp(block.timestamp + 4 minutes);
        uint256 amountInCharlie = _take_UnderCollateralized(charlie, 1e18);

        StrategyState memory stateAfter = leverageManager.getStrategyState(ethLong2x);

        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);

        // 1% is max loss because 99% is min auction multiplier
        uint256 maxLoss = stateBefore.equity / 100;
        assertGe(stateAfter.equity, stateBefore.equity - maxLoss);

        // Check if user received correct amount of collateral
        assertEq(WETH.balanceOf(alice), 1e18);
        assertEq(WETH.balanceOf(bob), 1e18);
        assertEq(WETH.balanceOf(charlie), 1 * 1e18);

        // Auction should automatically be removed because strategy is back into healthy state
        (
            bool isOverCollateralized,
            uint256 initialPriceMultiplier,
            uint256 minPriceMultiplier,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = DutchAuctionRebalancer(dutchAuctionModule).auctions(ethLong2x);

        assertEq(isOverCollateralized, false);
        assertEq(startTimestamp, 0);
        assertEq(endTimestamp, 0);
        assertEq(minPriceMultiplier, 0);
        assertEq(initialPriceMultiplier, 0);

        assertLe(amountInBob, amountInAlice);
        assertLe(amountInCharlie, amountInBob);
    }

    function testFork_take_StrategyBackToHealthy() public {
        _prepareOverCollateralizedState();

        // Start auction
        DutchAuctionRebalancer(dutchAuctionModule).createAuction(ethLong2x);

        // Alice takes
        _take_OverCollateralized(alice, 2_000 * 1e6);

        _moveEthPrice(-15_00); // Move ETH price 15% down to bring strategy back to healthy state

        // Try to take and reverts
        vm.expectRevert(IDutchAuctionRebalancer.AuctionNotValid.selector);
        DutchAuctionRebalancer(dutchAuctionModule).take(ethLong2x, 1e18);
    }

    function _take_OverCollateralized(address user, uint256 amountOut) internal returns (uint256) {
        uint256 amountIn = DutchAuctionRebalancer(dutchAuctionModule).getAmountIn(ethLong2x, amountOut);
        deal(address(WETH), user, amountIn);

        vm.startPrank(user);
        WETH.approve(dutchAuctionModule, amountIn);
        DutchAuctionRebalancer(dutchAuctionModule).take(ethLong2x, amountOut);
        vm.stopPrank();

        return amountIn;
    }

    function _take_UnderCollateralized(address user, uint256 amountOut) internal returns (uint256) {
        uint256 amountIn = DutchAuctionRebalancer(dutchAuctionModule).getAmountIn(ethLong2x, amountOut);
        deal(address(USDC), user, amountIn);

        vm.startPrank(user);
        USDC.approve(dutchAuctionModule, amountIn);
        DutchAuctionRebalancer(dutchAuctionModule).take(ethLong2x, amountOut);
        vm.stopPrank();

        return amountIn;
    }
}
