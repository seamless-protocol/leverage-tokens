// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerTest} from "./DutchAuctionRebalancer.t.sol";
import {IDutchAuctionRebalancer} from "src/interfaces/IDutchAuctionRebalancer.sol";
import {CollateralRatios, StrategyState} from "src/types/DataTypes.sol";

contract GetStrategyRebalanceStatusTest is DutchAuctionRebalancerTest {
    function test_getStrategyRebalanceStatus_NotEligible_WithinBounds() public {
        // Set current ratio to be within bounds (e.g., 1.5x)
        _setStrategyCollateralRatio(1.5e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getStrategyRebalanceStatus(strategy);
        assertFalse(isEligible);
        assertFalse(isOverCollateralized); // Not relevant when not eligible
    }

    function test_getStrategyRebalanceStatus_Eligible_UnderCollateralized() public {
        // Set higher min ratio for this test
        _setStrategyCollateralRatios(1.5e8, MAX_RATIO, TARGET_RATIO);

        // Set current ratio to be below min (e.g., 1.4x)
        _setStrategyCollateralRatio(1.4e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getStrategyRebalanceStatus(strategy);
        assertTrue(isEligible);
        assertFalse(isOverCollateralized);
    }

    function test_getStrategyRebalanceStatus_Eligible_OverCollateralized() public {
        // Set current ratio to be above max (e.g., 3.1x)
        _setStrategyCollateralRatio(3.1e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getStrategyRebalanceStatus(strategy);
        assertTrue(isEligible);
        assertTrue(isOverCollateralized);
    }

    function testFuzz_getStrategyRebalanceStatus(
        uint256 minRatio,
        uint256 maxRatio,
        uint256 targetRatio,
        uint256 currentRatio
    ) public {
        // Ensure valid ratio bounds
        vm.assume(minRatio > 0);
        vm.assume(maxRatio > minRatio);
        vm.assume(targetRatio >= minRatio && targetRatio <= maxRatio);

        _setStrategyCollateralRatios(minRatio, maxRatio, targetRatio);
        _setStrategyCollateralRatio(currentRatio);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getStrategyRebalanceStatus(strategy);

        if (currentRatio < minRatio) {
            assertTrue(isEligible);
            assertFalse(isOverCollateralized);
        } else if (currentRatio > maxRatio) {
            assertTrue(isEligible);
            assertTrue(isOverCollateralized);
        } else {
            assertFalse(isEligible);
        }
    }
}
