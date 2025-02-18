// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract GetStrategyStateTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_getStrategyState() public {
        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: 200 ether,
                debt: 100 ether,
                targetRatio: uint128(_BASE_RATIO() + 1) // not important for this test
            })
        );

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateral, 200 ether);
        assertEq(state.debt, 100 ether);
        assertEq(state.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_getStrategyState_ZeroDebt() public {
        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: 200 ether,
                debt: 0,
                targetRatio: uint128(_BASE_RATIO() + 1) // not important for this test
            })
        );

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateral, 200 ether);
        assertEq(state.debt, 0);
        assertEq(state.collateralRatio, type(uint256).max);
    }
}
