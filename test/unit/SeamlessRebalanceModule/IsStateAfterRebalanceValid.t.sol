// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SeamlessRebalanceModuleBaseTest} from "./SeamlessRebalanceModuleBase.t.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsStateAfterRebalanceValidTest is SeamlessRebalanceModuleBaseTest {
    function setUp() public override {
        super.setUp();

        leverageManager.setLeverageTokenTargetCollateralRatio(leverageToken, TARGET_RATIO);
    }

    function test_isStateAfterRebalanceValid_WhenMovingCloserToTarget() public {
        // Initial state is at 3x, moving closer to 2x target
        LeverageTokenState memory stateBefore = LeverageTokenState({
            collateralInDebtAsset: 0, // Not important for this test
            debt: 0, // Not important for this test
            equity: 0, // Not important for this test
            collateralRatio: 3e8 // 3x
        });

        _mockCollateralRatio(2.5e8);

        vm.prank(address(leverageManager));
        bool isValid = rebalanceModule.isStateAfterRebalanceValid(leverageToken, stateBefore);
        assertTrue(isValid);
    }

    function test_isStateAfterRebalanceValid_WhenMovingAwayFromTarget() public {
        // Initial state is at 2.5x
        LeverageTokenState memory stateBefore = LeverageTokenState({
            collateralInDebtAsset: 0, // Not important for this test
            debt: 0, // Not important for this test
            equity: 0, // Not important for this test
            collateralRatio: 2.5e8 // 2.5x
        });

        _mockCollateralRatio(3e8);

        vm.prank(address(leverageManager));
        bool isValid = rebalanceModule.isStateAfterRebalanceValid(leverageToken, stateBefore);
        assertFalse(isValid);
    }

    function test_isStateAfterRebalanceValid_WhenCrossingTarget() public {
        // Initial state is at 2.5x
        LeverageTokenState memory stateBefore = LeverageTokenState({
            collateralInDebtAsset: 0, // Not important for this test
            debt: 0, // Not important for this test
            equity: 0, // Not important for this test
            collateralRatio: 2.5e8 // 2.5x
        });

        _mockCollateralRatio(1.4e8);

        vm.prank(address(leverageManager));
        bool isValid = rebalanceModule.isStateAfterRebalanceValid(leverageToken, stateBefore);
        assertFalse(isValid);
    }

    function testFuzz_isStateAfterRebalanceValid_LeverageTokenProperlyRebalanced(
        uint256 ratioBefore,
        uint256 ratioAfter
    ) public {
        if (ratioBefore > 2e8) {
            ratioAfter = bound(ratioAfter, 2e8, ratioBefore);
        } else {
            ratioAfter = bound(ratioAfter, ratioBefore, 2e8);
        }

        LeverageTokenState memory stateBefore = LeverageTokenState({
            collateralInDebtAsset: 0, // Not important for this test
            debt: 0, // Not important for this test
            equity: 0, // Not important for this test
            collateralRatio: ratioBefore
        });

        _mockCollateralRatio(ratioAfter);

        vm.prank(address(leverageManager));
        bool isValid = rebalanceModule.isStateAfterRebalanceValid(leverageToken, stateBefore);
        assertTrue(isValid);
    }

    function testFuzz_isStateAfterRebalanceValid_LeverageTokenNotProperlyRebalanced(
        uint256 ratioBefore,
        uint256 ratioAfter
    ) public {
        if (ratioBefore > 2e8) {
            ratioAfter = bound(ratioAfter, ratioBefore, type(uint256).max);
        } else {
            ratioAfter = bound(ratioAfter, 0, ratioBefore);
        }

        vm.assume(ratioBefore != ratioAfter);

        LeverageTokenState memory stateBefore = LeverageTokenState({
            collateralInDebtAsset: 0, // Not important for this test
            debt: 0, // Not important for this test
            equity: 0, // Not important for this test
            collateralRatio: ratioBefore
        });

        _mockCollateralRatio(ratioAfter);

        vm.prank(address(leverageManager));
        bool isValid = rebalanceModule.isStateAfterRebalanceValid(leverageToken, stateBefore);
        assertFalse(isValid);
    }
}
