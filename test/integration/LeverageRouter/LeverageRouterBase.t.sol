// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
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
    address public constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_SLIPSTREAM_ROUTER = 0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5;
    address public constant AERODROME_POOL_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant UNISWAP_V2_ROUTER02 = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant UNISWAP_SWAP_ROUTER02 = 0x2626664c2603336E57B271c5C0b26F421741e481;

    ILeverageRouter public leverageRouter;
    ISwapAdapter public swapAdapter;

    function setUp() public virtual override {
        super.setUp();

        address swapAdapterImplementation = address(new SwapAdapter());
        swapAdapter = ISwapAdapter(
            UnsafeUpgrades.deployUUPSProxy(
                swapAdapterImplementation, abi.encodeWithSelector(SwapAdapter.initialize.selector, address(this))
            )
        );

        leverageRouter = new LeverageRouter(leverageManager, MORPHO, swapAdapter);

        vm.label(address(leverageRouter), "leverageRouter");
        vm.label(address(swapAdapter), "swapAdapter");
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
