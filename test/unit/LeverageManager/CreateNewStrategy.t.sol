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
import {StrategyConfig} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";

contract CreateNewStrategyTest is LeverageManagerBaseTest {
    function testFuzz_CreateNewStrategy(
        StrategyConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.strategyDepositFee = bound(config.strategyDepositFee, 0, _MAX_FEE());
        config.strategyWithdrawFee = bound(config.strategyWithdrawFee, 0, _MAX_FEE());

        address expectedStrategyAddress = strategyTokenFactory.computeProxyAddress(
            address(leverageManager),
            abi.encodeWithSelector(Strategy.initialize.selector, address(leverageManager), name, symbol),
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
        StrategyConfig memory configAfter = leverageManager.getStrategyConfig(strategy);
        assertEq(address(configAfter.lendingAdapter), address(config.lendingAdapter));
        assertEq(address(configAfter.rebalanceModule), address(config.rebalanceModule));

        assertEq(configAfter.strategyDepositFee, config.strategyDepositFee);
        assertEq(configAfter.strategyWithdrawFee, config.strategyWithdrawFee);

        assertEq(address(leverageManager.getStrategyCollateralAsset(strategy)), collateralAsset);
        assertEq(address(leverageManager.getStrategyDebtAsset(strategy)), debtAsset);

        assertEq(leverageManager.getIsLendingAdapterUsed(address(config.lendingAdapter)), true);
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), config.targetCollateralRatio);
    }

    function test_CreateNewStrategy_RevertIf_LendingAdapterAlreadyInUse(
        StrategyConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) public {
        config.strategyDepositFee = bound(config.strategyDepositFee, 0, _MAX_FEE());
        config.strategyWithdrawFee = bound(config.strategyWithdrawFee, 0, _MAX_FEE());

        _createNewStrategy(manager, config, collateralAsset, debtAsset, name, symbol);

        vm.expectRevert(
            abi.encodeWithSelector(ILeverageManager.LendingAdapterAlreadyInUse.selector, address(config.lendingAdapter))
        );
        _createNewStrategy(manager, config, collateralAsset, debtAsset, name, symbol);
    }
}
