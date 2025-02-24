// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {StrategyState} from "src/types/DataTypes.sol";

contract GetStrategyStateTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createDummyStrategy();
    }

    function test_getStrategyState() public {
        _mockStrategyCollateralInDebtAsset(200 ether);
        _mockStrategyDebt(100 ether);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateralInDebtAsset, 200 ether);
        assertEq(state.debt, 100 ether);
        assertEq(state.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_getStrategyState_ZeroDebt() public {
        _mockStrategyCollateralInDebtAsset(200 ether);
        _mockStrategyDebt(0);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateralInDebtAsset, 200 ether);
        assertEq(state.debt, 0);
        assertEq(state.collateralRatio, type(uint256).max);
    }
}
