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

contract SetStrategyCoreTest is LeverageManagerBaseTest {
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
}
