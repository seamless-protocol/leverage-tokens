// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

contract GetLeverageTokenStateTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();

        _createDummyLeverageToken();
    }

    function test_getLeverageTokenState() public {
        _mockLeverageTokenCollateralInDebtAsset(200 ether);
        _mockLeverageTokenDebt(100 ether);

        LeverageTokenState memory state = leverageManager.getLeverageTokenState(leverageToken);
        assertEq(state.collateralInDebtAsset, 200 ether);
        assertEq(state.debt, 100 ether);
        assertEq(state.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_getLeverageTokenState_ZeroDebt() public {
        _mockLeverageTokenCollateralInDebtAsset(200 ether);
        _mockLeverageTokenDebt(0);

        LeverageTokenState memory state = leverageManager.getLeverageTokenState(leverageToken);
        assertEq(state.collateralInDebtAsset, 200 ether);
        assertEq(state.debt, 0);
        assertEq(state.collateralRatio, type(uint256).max);
    }
}
