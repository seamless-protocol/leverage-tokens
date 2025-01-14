// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract CreateNewStrategyTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_CreateNewStrategy(Storage.StrategyConfig calldata config) public {
        vm.assume(config.collateralAsset != address(0) && config.debtAsset != address(0));

        uint256 minCollateralRatio = config.minCollateralRatio;
        uint256 targetCollateralRatio = config.targetCollateralRatio;
        uint256 maxCollateralRatio = config.maxCollateralRatio;
        vm.assume(
            targetCollateralRatio > _BASE_RATIO() && minCollateralRatio <= targetCollateralRatio
                && targetCollateralRatio <= maxCollateralRatio
        );

        // Check if event is emitted properly
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCreated(strategyId, config.collateralAsset, config.debtAsset);

        _createNewStrategy(manager, config);

        // Check if the strategy core is set correctly
        Storage.StrategyConfig memory configAfter = leverageManager.getStrategyConfig(strategyId);
        assertEq(configAfter.collateralAsset, config.collateralAsset);
        assertEq(configAfter.debtAsset, config.debtAsset);
        assertEq(address(configAfter.lendingAdapter), address(config.lendingAdapter));
        assertEq(configAfter.collateralCap, config.collateralCap);

        CollateralRatios memory ratios = leverageManager.getStrategyCollateralRatios(strategyId);
        assertEq(ratios.minCollateralRatio, config.minCollateralRatio);
        assertEq(ratios.maxCollateralRatio, config.maxCollateralRatio);
        assertEq(ratios.targetCollateralRatio, config.targetCollateralRatio);

        // Check if single getter functions return the correct values
        assertEq(leverageManager.getStrategyCollateralAsset(strategyId), config.collateralAsset);
        assertEq(leverageManager.getStrategyDebtAsset(strategyId), config.debtAsset);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_CreateNewStrategy_RevertIf_StrategyAlreadyExists(
        Storage.StrategyConfig calldata config1,
        Storage.StrategyConfig calldata config2
    ) public {
        vm.assume(config1.collateralAsset != address(0) && config1.debtAsset != address(0));
        vm.assume(config2.collateralAsset != address(0) && config2.debtAsset != address(0));
        vm.assume(address(config1.lendingAdapter) != address(0) && address(config2.lendingAdapter) != address(0));
        vm.assume(
            config1.targetCollateralRatio > _BASE_RATIO() && config1.minCollateralRatio <= config1.targetCollateralRatio
                && config1.targetCollateralRatio <= config1.maxCollateralRatio
        );

        _createNewStrategy(manager, config1);
        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.StrategyAlreadyExists.selector, strategyId));
        _createNewStrategy(manager, config2);
    }

    // forge-config: default.fuzz.runs = 1
    function testFuzz_CreateNewStrategy_RevertIf_AssetsAreInvalid(address nonZeroAddress) public {
        vm.assume(nonZeroAddress != address(0));

        Storage.StrategyConfig memory config = Storage.StrategyConfig({
            collateralAsset: address(0),
            debtAsset: nonZeroAddress,
            lendingAdapter: ILendingAdapter(nonZeroAddress),
            minCollateralRatio: _BASE_RATIO(),
            targetCollateralRatio: _BASE_RATIO() + 1,
            maxCollateralRatio: _BASE_RATIO() + 2,
            collateralCap: 0
        });

        // Revert if collateral is zero address
        vm.expectRevert(ILeverageManager.InvalidStrategyAssets.selector);
        _createNewStrategy(manager, config);

        // Revert if debt is zero address
        config.collateralAsset = nonZeroAddress;
        config.debtAsset = address(0);

        vm.expectRevert(ILeverageManager.InvalidStrategyAssets.selector);
        _createNewStrategy(manager, config);

        // Revert if both collateral and debt are zero addresses
        config.collateralAsset = address(0);

        vm.expectRevert(ILeverageManager.InvalidStrategyAssets.selector);
        _createNewStrategy(manager, config);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_CreateNewStrategy_RevertIf_CallerIsNotManager(
        address caller,
        Storage.StrategyConfig calldata config
    ) public {
        vm.assume(caller != manager);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, leverageManager.MANAGER_ROLE()
            )
        );
        _createNewStrategy(caller, config);
    }
}
