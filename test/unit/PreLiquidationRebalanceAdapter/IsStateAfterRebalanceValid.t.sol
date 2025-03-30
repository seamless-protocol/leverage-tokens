// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PreLiquidationRebalanceAdapterTest} from "./PreLiquidationRebalanceAdapter.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract IsStateAfterRebalanceValidTest is PreLiquidationRebalanceAdapterTest {
    function test_isStateAfterRebalanceValid_ValidState() public {
        // Mock liquidation penalty to 5% and equity 97.6
        _mockLiquidationPenaltyAndEquity(0.05e18, 97.5e18);

        // Max equity loss here should be 2.5%
        LeverageTokenState memory stateBefore =
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: 100e18});

        assertEq(adapter.isStateAfterRebalanceValid(leverageToken, stateBefore), true);
    }

    function testFuzz_isStateAfterRebalanceValid_AlwaysPassIfEquityIsBiggerOrEqual(
        uint128 liquidationPenalty,
        uint128 equityBefore,
        uint128 equityAfter
    ) public {
        liquidationPenalty = uint128(bound(liquidationPenalty, 0, 1e18));
        equityAfter = uint128(bound(equityAfter, equityBefore, type(uint128).max));

        // Mock liquidation penalty to 5% and equity to 100
        _mockLiquidationPenaltyAndEquity(liquidationPenalty, equityAfter);

        LeverageTokenState memory stateBefore =
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: equityBefore});

        assertEq(adapter.isStateAfterRebalanceValid(leverageToken, stateBefore), true);
    }

    function test_isStateAfterRebalanceValid_InvalidState() public {
        // Mock liquidation penalty to 5% and equity to 97.5 - 1wei
        _mockLiquidationPenaltyAndEquity(0.05e18, 97.5e18 - 1);

        LeverageTokenState memory stateBefore =
            LeverageTokenState({collateralRatio: 0, collateralInDebtAsset: 0, debt: 0, equity: 100e18});

        assertEq(adapter.isStateAfterRebalanceValid(leverageToken, stateBefore), false);
    }
}
