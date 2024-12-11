// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract CalculateExcessOfCollateralTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_calculateExcessOfCollateral_ExcessExists() public {
        address strategy = makeAddr("strategy");
        uint128 collateralInDebt = 3000 ether;
        uint128 debt = 1000 ether;
        uint256 targetRatio = 2 * BASE_RATIO; // 2x leverage

        _mockState_CalculateExcessOfCollateral(
            CalculateExcessOfCollateralState({
                strategy: strategy,
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 excess = leverageManager.calculateExcessOfCollateral(strategy, leverageManager.getLendingContract());
        assertEq(excess, 1000 ether);
    }

    function test_calculateExcessOfCollateral_ExcessDoesNotExist() public {
        address strategy = makeAddr("strategy");
        uint128 collateralInDebt = 1999 ether;
        uint128 debt = 1000 ether;
        uint256 targetRatio = 2 * BASE_RATIO; // 2x leverage

        _mockState_CalculateExcessOfCollateral(
            CalculateExcessOfCollateralState({
                strategy: strategy,
                collateralInDebt: collateralInDebt,
                debt: debt,
                targetRatio: targetRatio
            })
        );

        uint256 excess = leverageManager.calculateExcessOfCollateral(strategy, leverageManager.getLendingContract());
        assertEq(excess, 0);
    }

    function testFuzz_calculateExcessOfCollateral_ExcessExists(CalculateExcessOfCollateralState memory state) public {
        state.targetRatio = bound(state.targetRatio, BASE_RATIO, 200 * BASE_RATIO);

        uint128 collateralInDebt = state.collateralInDebt;
        uint128 debt = state.debt;
        uint256 targetRatio = state.targetRatio;

        vm.assume(collateralInDebt > debt * targetRatio / BASE_RATIO + 1);

        _mockState_CalculateExcessOfCollateral(state);

        uint256 excess =
            leverageManager.calculateExcessOfCollateral(state.strategy, leverageManager.getLendingContract());

        uint256 expectedExcess = collateralInDebt - Math.mulDiv(debt, targetRatio, BASE_RATIO, Math.Rounding.Ceil);
        assertEq(excess, expectedExcess);
    }

    function testFuzz_calculateExcessOfCollateral_ExcessDoesNotExist(CalculateExcessOfCollateralState memory state)
        public
    {
        state.targetRatio = bound(state.targetRatio, BASE_RATIO, 200 * BASE_RATIO);
        vm.assume(state.collateralInDebt < state.debt * state.targetRatio / BASE_RATIO + 1);

        _mockState_CalculateExcessOfCollateral(state);

        uint256 excess =
            leverageManager.calculateExcessOfCollateral(state.strategy, leverageManager.getLendingContract());
        assertEq(excess, 0);
    }
}
