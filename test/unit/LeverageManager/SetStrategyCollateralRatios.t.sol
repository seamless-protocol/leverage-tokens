// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract SetStrategyCollateralRatiosTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCollateralRatios(CollateralRatios memory ratios) public {
        vm.assume(
            ratios.targetCollateralRatio > _BASE_RATIO() && ratios.minCollateralRatio <= ratios.targetCollateralRatio
                && ratios.targetCollateralRatio <= ratios.maxCollateralRatio
        );

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCollateralRatiosSet(strategyId, ratios);

        _setStrategyCollateralRatios(manager, ratios);

        // Check if the collateral ratios are set correctly
        CollateralRatios memory ratiosAfterSet = leverageManager.getStrategyCollateralRatios(strategyId);
        assertEq(ratiosAfterSet.minCollateralRatio, ratios.minCollateralRatio);
        assertEq(ratiosAfterSet.maxCollateralRatio, ratios.maxCollateralRatio);
        assertEq(ratiosAfterSet.targetCollateralRatio, ratios.targetCollateralRatio);

        // Check that getter for targetCollateralRatio ratio returns the correct value
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategyId), ratios.targetCollateralRatio);
    }

    // If target ratio is not in between min and max ratios, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_InvalidCollateralRatios(CollateralRatios memory ratios)
        public
    {
        vm.assume(
            ratios.targetCollateralRatio <= _BASE_RATIO() || ratios.minCollateralRatio > ratios.targetCollateralRatio
                || ratios.maxCollateralRatio < ratios.targetCollateralRatio
        );
        vm.expectRevert(ILeverageManager.InvalidCollateralRatios.selector);
        _setStrategyCollateralRatios(manager, ratios);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_setStrategyCollateralRatios_RevertIf_CallerIsNotManager(
        address caller,
        CollateralRatios memory ratios
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCollateralRatios(caller, ratios);

        vm.stopPrank();
    }
}
