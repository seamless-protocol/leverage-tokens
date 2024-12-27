// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "../LeverageManagerBase.t.sol";

contract SetStrategyCollateralRatiosTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCollateralRatios(Storage.CollateralRatios memory ratios) public {
        vm.assume(
            ratios.minCollateralRatio <= ratios.targetCollateralRatio
                && ratios.targetCollateralRatio <= ratios.maxCollateralRatio
        );

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCollateralRatiosSet(strategy, ratios);

        _setStrategyCollateralRatios(manager, ratios);

        // Check if the collateral ratios are set correctly
        Storage.CollateralRatios memory ratiosAfterSet = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratiosAfterSet.minCollateralRatio, ratios.minCollateralRatio);
        assertEq(ratiosAfterSet.maxCollateralRatio, ratios.maxCollateralRatio);
        assertEq(ratiosAfterSet.targetCollateralRatio, ratios.targetCollateralRatio);

        // Check that getter for targetCollateralRatio ratio returns the correct value
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), ratios.targetCollateralRatio);
    }

    // If target ratio is not in between min and max ratios, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_InvalidCollateralRatios(
        Storage.CollateralRatios memory ratios
    ) public {
        vm.assume(
            ratios.minCollateralRatio > ratios.targetCollateralRatio
                || ratios.maxCollateralRatio < ratios.targetCollateralRatio
        );
        vm.expectRevert(ILeverageManager.InvalidCollateralRatios.selector);
        _setStrategyCollateralRatios(manager, ratios);
    }

    // If caller is not the manager, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_CallerIsNotManager(Storage.CollateralRatios memory ratios)
        public
    {
        address caller = makeAddr("caller");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCollateralRatios(caller, ratios);

        vm.stopPrank();
    }
}
