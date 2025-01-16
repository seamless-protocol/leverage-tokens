// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";
import {Strategy} from "src/Strategy.sol";

contract CreateNewStrategyTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
    }

    function testFuzz_CreateNewStrategy(
        Storage.StrategyConfig calldata config,
        string memory name,
        string memory symbol
    ) public {
        uint256 minCollateralRatio = config.minCollateralRatio;
        uint256 targetCollateralRatio = config.targetCollateralRatio;
        uint256 maxCollateralRatio = config.maxCollateralRatio;
        vm.assume(
            targetCollateralRatio > _BASE_RATIO() && minCollateralRatio <= targetCollateralRatio
                && targetCollateralRatio <= maxCollateralRatio
        );

        address expectedStrategyAddress = strategyTokenFactory.computeProxyAddress(
            address(leverageManager),
            abi.encodeWithSelector(Strategy.initialize.selector, address(leverageManager), name, symbol),
            0
        );

        // Check if event is emitted properly
        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.StrategyCreated(IStrategy(expectedStrategyAddress));

        _createNewStrategy(manager, config, name, symbol);

        // Check name of the strategy token
        assertEq(IERC20Metadata(expectedStrategyAddress).name(), name);
        assertEq(IERC20Metadata(expectedStrategyAddress).symbol(), symbol);

        // Check if the strategy core is set correctly
        Storage.StrategyConfig memory configAfter = leverageManager.getStrategyConfig(strategy);
        assertEq(address(configAfter.lendingAdapter), address(config.lendingAdapter));
        assertEq(configAfter.collateralCap, config.collateralCap);

        CollateralRatios memory ratios = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratios.minCollateralRatio, config.minCollateralRatio);
        assertEq(ratios.maxCollateralRatio, config.maxCollateralRatio);
        assertEq(ratios.targetCollateralRatio, config.targetCollateralRatio);
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
        _createNewStrategy(caller, config, "", "");
    }
}
