// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";

contract CreateNewStrategyTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_CreateNewStrategy(
        ILeverageManager.StrategyConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.targetCollateralRatio = bound(config.minCollateralRatio, _BASE_RATIO() + 1, type(uint256).max - 1);
        config.minCollateralRatio = bound(config.minCollateralRatio, _BASE_RATIO(), config.targetCollateralRatio - 1);
        config.maxCollateralRatio =
            bound(config.maxCollateralRatio, config.targetCollateralRatio + 1, type(uint256).max);

        address expectedStrategyAddress = strategyTokenFactory.computeProxyAddress(
            address(leverageManager),
            abi.encodeWithSelector(Strategy.initialize.selector, address(this), address(leverageManager), name, symbol),
            0
        );

        // Check if event is emitted properly
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCreated(
            IStrategy(expectedStrategyAddress), IERC20(collateralAsset), IERC20(debtAsset), config
        );

        _createNewStrategy(manager, config, collateralAsset, debtAsset, name, symbol);

        // Check name of the strategy token
        assertEq(IERC20Metadata(expectedStrategyAddress).name(), name);
        assertEq(IERC20Metadata(expectedStrategyAddress).symbol(), symbol);

        // Check if the strategy core is set correctly
        ILeverageManager.StrategyConfig memory configAfter = leverageManager.getStrategyConfig(strategy);
        assertEq(address(configAfter.lendingAdapter), address(config.lendingAdapter));

        CollateralRatios memory ratios = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratios.minCollateralRatio, config.minCollateralRatio);
        assertEq(ratios.maxCollateralRatio, config.maxCollateralRatio);
        assertEq(ratios.targetCollateralRatio, config.targetCollateralRatio);

        assertEq(address(leverageManager.getStrategyCollateralAsset(strategy)), collateralAsset);
        assertEq(address(leverageManager.getStrategyDebtAsset(strategy)), debtAsset);

        assertEq(leverageManager.getIsLendingAdapterUsed(address(config.lendingAdapter)), true);
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), config.targetCollateralRatio);
        assertEq(
            address(leverageManager.getStrategyRebalanceRewardDistributor(strategy)),
            address(config.rebalanceRewardDistributor)
        );
        assertEq(address(leverageManager.getStrategyRebalanceWhitelist(strategy)), address(config.rebalanceWhitelist));
    }

    function test_CreateNewStrategy_RevertIf_LendingAdapterAlreadyInUse(
        ILeverageManager.StrategyConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.targetCollateralRatio = bound(config.minCollateralRatio, _BASE_RATIO() + 1, type(uint256).max - 1);
        config.minCollateralRatio = bound(config.minCollateralRatio, _BASE_RATIO(), config.targetCollateralRatio - 1);
        config.maxCollateralRatio =
            bound(config.maxCollateralRatio, config.targetCollateralRatio + 1, type(uint256).max);

        _createNewStrategy(manager, config, collateralAsset, debtAsset, name, symbol);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.LendingAdapterAlreadyInUse.selector, address(config.lendingAdapter))
        );
        _createNewStrategy(manager, config, collateralAsset, debtAsset, name, symbol);
    }
}
