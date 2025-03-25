// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsEligibleForRebalanceTest is SeamlessRebalanceModuleBaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(defaultAdmin);
        rebalanceModule.setIsRebalancer(dutchAuctionModule, true);
        rebalanceModule.setLeverageTokenCollateralRatios(leverageToken, 1.5 * 1e8, 2.5 * 1e8);
        vm.stopPrank();
    }

    function test_isEligibleForRebalance_WhenCollateralRatioTooLow() public view {
        LeverageTokenState memory state =
            LeverageTokenState({collateralInDebtAsset: 100 ether, debt: 100 ether, equity: 0, collateralRatio: 1e8});

        bool isEligible = rebalanceModule.isEligibleForRebalance(leverageToken, state, dutchAuctionModule);
        assertTrue(isEligible);
    }

    function test_isEligibleForRebalance_WhenCollateralRatioTooHigh() public view {
        LeverageTokenState memory state = LeverageTokenState({
            collateralInDebtAsset: 300 ether,
            debt: 100 ether,
            equity: 200 ether,
            collateralRatio: 3e8
        });

        bool isEligible = rebalanceModule.isEligibleForRebalance(leverageToken, state, dutchAuctionModule);
        assertTrue(isEligible);
    }

    function test_isEligibleForRebalance_WhenCollateralRatioInRange() public view {
        LeverageTokenState memory state = LeverageTokenState({
            collateralInDebtAsset: 200 ether,
            debt: 100 ether,
            equity: 100 ether,
            collateralRatio: 2e8
        });

        bool isEligible = rebalanceModule.isEligibleForRebalance(leverageToken, state, dutchAuctionModule);
        assertFalse(isEligible);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_isEligibleForRebalance_WhenCallerNotDutchAuctionModule(
        address caller,
        LeverageTokenState memory state
    ) public view {
        vm.assume(caller != dutchAuctionModule);

        bool isEligible = rebalanceModule.isEligibleForRebalance(leverageToken, state, caller);
        assertFalse(isEligible);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_isEligibleForRebalance(uint256 collateralRatio) public view {
        uint256 minRatio = rebalanceModule.getLeverageTokenMinCollateralRatio(leverageToken);
        uint256 maxRatio = rebalanceModule.getLeverageTokenMaxCollateralRatio(leverageToken);

        LeverageTokenState memory state = LeverageTokenState({
            collateralInDebtAsset: 100 ether,
            debt: 100 ether,
            equity: 0,
            collateralRatio: collateralRatio
        });

        bool isEligible = rebalanceModule.isEligibleForRebalance(leverageToken, state, dutchAuctionModule);
        bool shouldBeEligible = collateralRatio < minRatio || collateralRatio > maxRatio;

        assertEq(isEligible, shouldBeEligible);
    }
}
