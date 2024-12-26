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

contract SetStrategyCoreTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_SetStrategyCore(address strategy, Storage.StrategyCore calldata core) public {
        vm.assume(core.collateral != address(0) && core.debt != address(0));

        // Check if event is emitted properly
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCoreSet(strategy, core);

        _setStrategyCore(manager, strategy, core);

        // Check if the strategy core is set correctly
        Storage.StrategyCore memory coreAfter = leverageManager.getStrategyCore(strategy);
        assertEq(coreAfter.collateral, core.collateral);
        assertEq(coreAfter.debt, core.debt);

        // Check if single getter functions return the correct values
        assertEq(leverageManager.getStrategyCollateralAsset(strategy), core.collateral);
        assertEq(leverageManager.getStrategyDebtAsset(strategy), core.debt);
    }

    // Core configuration of the strategy can be set only once
    function testFuzz_SetStrategyCore_RevertIf_CoreIsAlreadySet(
        address strategy,
        Storage.StrategyCore calldata core1,
        Storage.StrategyCore calldata core2
    ) public {
        vm.assume(core1.collateral != address(0) && core1.debt != address(0));
        vm.assume(core2.collateral != address(0) && core2.debt != address(0));

        _setStrategyCore(manager, strategy, core1);

        vm.expectRevert(ILeverageManager.CoreAlreadySet.selector);
        _setStrategyCore(manager, strategy, core2);
    }

    // Neither collateral nor debt asset can be zero address
    function testFuzz_SetStrategyCore_RevertIf_CoreConfigIsInvalid(address strategy, address nonZeroAddress) public {
        vm.assume(nonZeroAddress != address(0));

        // Revert if collateral is zero address
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        _setStrategyCore(manager, strategy, Storage.StrategyCore({collateral: address(0), debt: nonZeroAddress}));

        // Revert if debt is zero address
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        _setStrategyCore(manager, strategy, Storage.StrategyCore({collateral: nonZeroAddress, debt: address(0)}));

        // Revert if both collateral and debt are zero addresses
        vm.expectRevert(ILeverageManager.InvalidStrategyCore.selector);
        _setStrategyCore(manager, strategy, Storage.StrategyCore({collateral: address(0), debt: address(0)}));
    }

    // Only manager can set core configuration of the strategy
    function testFuzz_SetStrategyCore_RevertIf_CallerIsNotManager(
        address caller,
        address strategy,
        Storage.StrategyCore calldata core
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _setStrategyCore(caller, strategy, core);
    }
}
