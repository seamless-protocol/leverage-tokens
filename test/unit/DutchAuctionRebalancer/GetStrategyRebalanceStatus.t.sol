// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {DutchAuctionRebalancerBaseTest} from "./DutchAuctionRebalancerBase.t.sol";

contract GetLeverageTokenRebalanceStatusTest is DutchAuctionRebalancerBaseTest {
    function test_getLeverageTokenRebalanceStatus_NotEligible_WithinBounds() public {
        // Set current ratio to be within bounds (e.g., 1.5x)
        _setLeverageTokenCollateralRatio(1.5e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getLeverageTokenRebalanceStatus(leverageToken);
        assertFalse(isEligible);
        assertFalse(isOverCollateralized); // Not relevant when not eligible
    }

    function test_getLeverageTokenRebalanceStatus_Eligible_UnderCollateralized() public {
        // Set higher min ratio for this test
        _mockLeverageTokenCollateralRatios(1.5e8, MAX_RATIO);

        // Set current ratio to be below min (e.g., 1.4x)
        _setLeverageTokenCollateralRatio(1.4e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getLeverageTokenRebalanceStatus(leverageToken);
        assertTrue(isEligible);
        assertFalse(isOverCollateralized);
    }

    function test_getLeverageTokenRebalanceStatus_Eligible_OverCollateralized() public {
        // Set current ratio to be above max (e.g., 3.1x)
        _setLeverageTokenCollateralRatio(3.1e8);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getLeverageTokenRebalanceStatus(leverageToken);
        assertTrue(isEligible);
        assertTrue(isOverCollateralized);
    }

    function testFuzz_getLeverageTokenRebalanceStatus(
        uint256 minRatio,
        uint256 maxRatio,
        uint256 targetRatio,
        uint256 currentRatio
    ) public {
        // Ensure valid ratio bounds
        vm.assume(minRatio > 0);
        vm.assume(maxRatio > minRatio);
        vm.assume(targetRatio >= minRatio && targetRatio <= maxRatio);

        _mockLeverageTokenCollateralRatios(minRatio, maxRatio);
        _setLeverageTokenCollateralRatio(currentRatio);

        (bool isEligible, bool isOverCollateralized) = auctionRebalancer.getLeverageTokenRebalanceStatus(leverageToken);

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
