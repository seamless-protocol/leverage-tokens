// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract LeverageManagerRolesTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_SetStrategyCore(address strategy, address collateral, address debt) public {
        vm.assume(collateral != address(0) && debt != address(0));

        vm.prank(manager);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: collateral, debt: debt}));

        // Check if the strategy core is set correctly
        Storage.StrategyCore memory core = leverageManager.getStrategyCore(strategy);
        assertEq(core.collateral, collateral);
        assertEq(core.debt, debt);

        // Check if single getter functions return the correct values
        assertEq(leverageManager.getStrategyCollateralAsset(strategy), collateral);
        assertEq(leverageManager.getStrategyDebtAsset(strategy), debt);
    }

    // Core configuration of the strategy can be set only once
    function testFuzz_SetStrategyCore_RevertIf_CoreIsAlreadySet(address strategy, address collateral, address debt)
        public
    {
        vm.assume(collateral != address(0) && debt != address(0));

        vm.startPrank(manager);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: collateral, debt: debt}));

        vm.expectRevert(ILeverageManager.CoreAlreadySet.selector);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: collateral, debt: debt}));

        vm.stopPrank();
    }

    // Neither collateral nor debt asset can be zero address
    function testFuzz_SetStrategyCore_RevertIf_CoreConfigIsInvalid(address strategy, address nonZeroAddress) public {
        vm.assume(nonZeroAddress != address(0));
        vm.startPrank(manager);

        // Revert if collateral is zero address
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: address(0), debt: nonZeroAddress}));

        // Revert if debt is zero address
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: nonZeroAddress, debt: address(0)}));

        // Revert if both collateral and debt are zero addresses
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: address(0), debt: address(0)}));

        vm.stopPrank();
    }

    // Only manager can set core configuration of the strategy
    function testFuzz_SetStrategyCore_RevertIf_CallerIsNotManager(
        address caller,
        address strategy,
        address collateral,
        address debt
    ) public {
        vm.assume(caller != manager);

        vm.startPrank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        leverageManager.setStrategyCore(strategy, Storage.StrategyCore({collateral: collateral, debt: debt}));

        vm.stopPrank();
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

    function testFuzz_setStrategyCap(address strategy, uint256 cap) public {
        vm.prank(manager);
        leverageManager.setStrategyCap(strategy, cap);

        // Check if the strategy cap is set correctly
        assertEq(leverageManager.getStrategyCap(strategy), cap);
    }

    // If caller is not the manager, then the transaction should revert
    function testFuzz_setStrategyCap_RevertIf_CallerIsNotManager(address caller, address strategy, uint256 cap)
        public
    {
        vm.assume(caller != manager);

        vm.startPrank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        leverageManager.setStrategyCap(strategy, cap);

        vm.stopPrank();
    }
}
