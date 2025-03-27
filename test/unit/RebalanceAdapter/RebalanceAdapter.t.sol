// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {RebalanceAdapterHarness} from "test/unit/harness/RebalaneAdapterHarness.t.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";

contract RebalanceAdapterTest is Test {
    address public owner = makeAddr("owner");
    ILeverageManager public leverageManager = ILeverageManager(makeAddr("leverageManager"));
    ILeverageToken public leverageToken = ILeverageToken(makeAddr("leverageToken"));

    uint256 public minCollateralRatio = 1.5 * 1e8;
    uint256 public maxCollateralRatio = 2.5 * 1e8;
    uint256 public auctionDuration = 7 minutes;
    uint256 public initialPriceMultiplier = 1.02 * 1e8;
    uint256 public minPriceMultiplier = 0.99 * 1e8;

    RebalanceAdapterHarness public rebalanceAdapter;

    function setUp() public virtual {
        RebalanceAdapterHarness implementation = new RebalanceAdapterHarness();
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(implementation),
            abi.encodeWithSelector(
                RebalanceAdapter.initialize.selector,
                leverageToken,
                abi.encode(
                    owner,
                    leverageManager,
                    minCollateralRatio,
                    maxCollateralRatio,
                    auctionDuration,
                    initialPriceMultiplier,
                    minPriceMultiplier
                )
            )
        );

        rebalanceAdapter = RebalanceAdapterHarness(proxy);
    }

    function test_setUp() public view {
        assertEq(address(rebalanceAdapter.getLeverageManager()), address(leverageManager));
        assertEq(address(rebalanceAdapter.getLeverageToken()), address(leverageToken));
        assertEq(rebalanceAdapter.getLeverageTokenMinCollateralRatio(), minCollateralRatio);
        assertEq(rebalanceAdapter.getLeverageTokenMaxCollateralRatio(), maxCollateralRatio);
        assertEq(rebalanceAdapter.getAuctionDuration(), auctionDuration);
        assertEq(rebalanceAdapter.getInitialPriceMultiplier(), initialPriceMultiplier);
        assertEq(rebalanceAdapter.getMinPriceMultiplier(), minPriceMultiplier);
    }
}
