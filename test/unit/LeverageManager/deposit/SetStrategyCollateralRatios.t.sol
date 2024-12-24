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

    function testFuzz_setStrategyCollateralRatios(uint256 strategy, Storage.CollateralRatios memory ratios) public {
        vm.assume(ratios.minForRebalance <= ratios.target && ratios.target <= ratios.maxForRebalance);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCollateralRatiosSet(strategy, ratios);

        _setStrategyCollateralRatios(manager, strategy, ratios);

        // Check if the collateral ratios are set correctly
        Storage.CollateralRatios memory ratiosAfterSet = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratiosAfterSet.minForRebalance, ratios.minForRebalance);
        assertEq(ratiosAfterSet.maxForRebalance, ratios.maxForRebalance);
        assertEq(ratiosAfterSet.target, ratios.target);

        // Check that getter for target ratio returns the correct value
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), ratios.target);
    }

    // If target ratio is not in between min and max ratios, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_InvalidCollateralRatios(
        uint256 strategy,
        Storage.CollateralRatios memory ratios
    ) public {
        vm.assume(ratios.minForRebalance > ratios.target || ratios.maxForRebalance < ratios.target);
        vm.expectRevert(ILeverageManager.InvalidCollateralRatios.selector);
        _setStrategyCollateralRatios(manager, strategy, ratios);
    }

    // If caller is not the manager, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_CallerIsNotManager(
        address caller,
        uint256 strategy,
        Storage.CollateralRatios memory ratios
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCollateralRatios(caller, strategy, ratios);

        vm.stopPrank();
    }
}
