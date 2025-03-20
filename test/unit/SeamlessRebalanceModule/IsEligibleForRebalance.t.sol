// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract IsEligibleForRebalanceTest is SeamlessRebalanceModuleBaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(defaultAdmin);
        rebalanceModule.setStrategyCollateralRatios(strategy, 1.5 * 1e8, 2.5 * 1e8);
        vm.stopPrank();
    }

    function test_isEligibleForRebalance_WhenCollateralRatioTooLow() public {
        StrategyState memory state =
            StrategyState({collateralInDebtAsset: 100 ether, debt: 100 ether, equity: 0, collateralRatio: 1e8});

        bool isEligible = rebalanceModule.isEligibleForRebalance(strategy, state, dutchAuctionModule);
        assertTrue(isEligible);
    }

    function test_isEligibleForRebalance_WhenCollateralRatioTooHigh() public {
        StrategyState memory state =
            StrategyState({collateralInDebtAsset: 300 ether, debt: 100 ether, equity: 200 ether, collateralRatio: 3e8});

        bool isEligible = rebalanceModule.isEligibleForRebalance(strategy, state, dutchAuctionModule);
        assertTrue(isEligible);
    }

    function test_isEligibleForRebalance_WhenCollateralRatioInRange() public {
        StrategyState memory state =
            StrategyState({collateralInDebtAsset: 200 ether, debt: 100 ether, equity: 100 ether, collateralRatio: 2e8});

        bool isEligible = rebalanceModule.isEligibleForRebalance(strategy, state, dutchAuctionModule);
        assertFalse(isEligible);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_isEligibleForRebalance_WhenCallerNotDutchAuctionModule(address caller, StrategyState memory state)
        public
    {
        vm.assume(caller != dutchAuctionModule);

        bool isEligible = rebalanceModule.isEligibleForRebalance(strategy, state, caller);
        assertFalse(isEligible);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_isEligibleForRebalance(uint256 collateralRatio) public {
        uint256 minRatio = rebalanceModule.getStrategyMinCollateralRatio(strategy);
        uint256 maxRatio = rebalanceModule.getStrategyMaxCollateralRatio(strategy);

        StrategyState memory state = StrategyState({
            collateralInDebtAsset: 100 ether,
            debt: 100 ether,
            equity: 0,
            collateralRatio: collateralRatio
        });

        bool isEligible = rebalanceModule.isEligibleForRebalance(strategy, state, dutchAuctionModule);
        bool shouldBeEligible = collateralRatio < minRatio || collateralRatio > maxRatio;

        assertEq(isEligible, shouldBeEligible);
    }
}
