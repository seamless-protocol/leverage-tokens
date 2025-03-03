// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {Strategy} from "src/Strategy.sol";
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IntegrationTestBase} from "../IntegrationTestBase.t.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract LeverageRouterBase is IntegrationTestBase {
    uint256 public BASE_RATIO;
    address public user = makeAddr("user");
    IStrategy public strategy;

    ILeverageRouter public leverageRouter;

    ISwapAdapter public swapAdapter;

    function setUp() public virtual override {
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        leverageManager = ILeverageManager(
            UnsafeUpgrades.deployUUPSProxy(
                leverageManagerImplementation,
                abi.encodeWithSelector(LeverageManager.initialize.selector, address(this))
            )
        );
        LeverageManager(address(leverageManager)).grantRole(keccak256("FEE_MANAGER_ROLE"), address(this));

        address swapAdapterImplementation = address(new SwapAdapter());
        swapAdapter = ISwapAdapter(
            UnsafeUpgrades.deployUUPSProxy(
                swapAdapterImplementation, abi.encodeWithSelector(SwapAdapter.initialize.selector, address(this))
            )
        );

        leverageRouter = new LeverageRouter(leverageManager, MORPHO, swapAdapter);

        super.setUp();

        BASE_RATIO = LeverageManager(address(leverageManager)).BASE_RATIO();

        Strategy strategyImplementation = new Strategy();
        BeaconProxyFactory strategyFactory = new BeaconProxyFactory(address(strategyImplementation), address(this));

        leverageManager.setStrategyTokenFactory(address(strategyFactory));

        strategy = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(morphoLendingAdapter)),
                minCollateralRatio: BASE_RATIO,
                targetCollateralRatio: 2 * BASE_RATIO,
                maxCollateralRatio: 3 * BASE_RATIO,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "Seamless ETH/USDC 2x leverage token",
            "ltETH/USDC-2x"
        );

        vm.label(address(user), "user");
        vm.label(address(strategy), "strategy");
        vm.label(address(leverageRouter), "leverageRouter");
        vm.label(address(morphoLendingAdapter), "morphoLendingAdapter");
        vm.label(address(MORPHO), "MORPHO");
        vm.label(address(swapAdapter), "swapAdapter");
        vm.label(address(leverageManager), "leverageManager");
    }

    function testFork_setUp() public view override {
        assertEq(address(leverageManager.getStrategyCollateralAsset(strategy)), address(WETH));
        assertEq(address(leverageManager.getStrategyDebtAsset(strategy)), address(USDC));

        CollateralRatios memory ratios = leverageManager.getStrategyCollateralRatios(strategy);
        assertEq(ratios.minCollateralRatio, BASE_RATIO);
        assertEq(ratios.maxCollateralRatio, 3 * BASE_RATIO);
        assertEq(ratios.targetCollateralRatio, 2 * BASE_RATIO);

        assertEq(address(leverageManager.getStrategyRebalanceRewardDistributor(strategy)), address(0));
        assertEq(address(leverageManager.getStrategyRebalanceWhitelist(strategy)), address(0));

        assertEq(leverageManager.getIsLendingAdapterUsed(address(morphoLendingAdapter)), true);
        assertEq(leverageManager.getStrategyTargetCollateralRatio(strategy), 2 * BASE_RATIO);

        assertEq(address(leverageRouter.leverageManager()), address(leverageManager));
        assertEq(address(leverageRouter.morpho()), address(MORPHO));
        assertEq(address(leverageRouter.swapper()), address(swapAdapter));
    }
}
