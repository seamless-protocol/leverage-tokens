// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {BaseTest} from "./Base.t.sol";

contract SetStrategyCollateralRatiosTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_setStrategyCollateralRatios(
        address strategy,
        uint256 minForRebalance,
        uint256 maxForRebalance,
        uint256 target
    ) public {
        vm.assume(minForRebalance <= target && target <= maxForRebalance);

        vm.prank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({
                minForRebalance: minForRebalance,
                maxForRebalance: maxForRebalance,
                target: target
            })
        );

        // Check if the collateral ratios are set correctly
        Storage.CollateralRatios memory ratiosAfterSet = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratiosAfterSet.minForRebalance, minForRebalance);
        assertEq(ratiosAfterSet.maxForRebalance, maxForRebalance);
        assertEq(ratiosAfterSet.target, target);

        // Check that getter for target ratio returns the correct value
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), target);
    }

    // If target ratio is not in between min and max ratios, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_InvalidCollateralRatios(
        address strategy,
        uint256 minForRebalance,
        uint256 maxForRebalance,
        uint256 target
    ) public {
        vm.assume(minForRebalance > target || maxForRebalance < target);

        vm.prank(manager);

        vm.expectRevert(ILeverageManager.InvalidCollateralRatios.selector);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({
                minForRebalance: minForRebalance,
                maxForRebalance: maxForRebalance,
                target: target
            })
        );
    }

    // If caller is not the manager, then the transaction should revert
    function testFuzz_setStrategyCollateralRatios_RevertIf_CallerIsNotManager(
        address caller,
        address strategy,
        uint256 minForRebalance,
        uint256 maxForRebalance,
        uint256 target
    ) public {
        vm.assume(caller != manager);

        vm.startPrank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({
                minForRebalance: minForRebalance,
                maxForRebalance: maxForRebalance,
                target: target
            })
        );

        vm.stopPrank();
    }
}
