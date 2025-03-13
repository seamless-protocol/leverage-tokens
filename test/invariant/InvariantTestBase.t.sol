// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {Strategy} from "src/Strategy.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {LeverageManagerHandler} from "test/invariant/handlers/LeverageManagerHandler.t.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";

contract InvariantTestBase is Test {
    uint256 public BASE_RATIO;

    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");
    address public feeManagerRole = makeAddr("feeManagerRole");

    LeverageManagerHarness public leverageManager;
    LeverageManagerHandler public leverageManagerHandler;

    function setUp() public {
        address strategyTokenImplementation = address(new Strategy());

        BeaconProxyFactory strategyTokenFactory = new BeaconProxyFactory(strategyTokenImplementation, address(this));
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
        );
        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
        leverageManager.setStrategyTokenFactory(address(strategyTokenFactory));
        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);
        vm.stopPrank();

        BASE_RATIO = leverageManager.BASE_RATIO();

        _initLeverageManagerHandler(leverageManager);

        targetContract(address(leverageManagerHandler));
        targetSelector(FuzzSelector({addr: address(leverageManagerHandler), selectors: _fuzzedSelectors()}));
    }

    function invariant_callSummary() public view {
        leverageManagerHandler.callSummary();
    }

    function _createActors(uint256 numActors) internal returns (address[] memory) {
        address[] memory actors = new address[](numActors);
        for (uint256 i = 0; i < numActors; i++) {
            actors[i] = makeAddr(string.concat("actor-", Strings.toString(i)));
        }
        return actors;
    }

    function _fuzzedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = LeverageManagerHandler.deposit.selector;
        selectors[1] = LeverageManagerHandler.addCollateral.selector;
        selectors[2] = LeverageManagerHandler.repayDebt.selector;
        return selectors;
    }

    function _initLeverageManagerHandler(LeverageManagerHarness _leverageManager) internal {
        IStrategy[] memory strategies = new IStrategy[](2);
        strategies[0] = _initStrategy(
            3 * BASE_RATIO / 2, // 1.5x
            3 * BASE_RATIO, // 3x
            2 * BASE_RATIO, // 2x
            IRebalanceRewardDistributor(address(0)),
            IRebalanceWhitelist(address(0)),
            "Strategy A",
            "STRAT-A"
        );
        strategies[1] = _initStrategy(
            5 * BASE_RATIO - 1, // 5x - 1
            5 * BASE_RATIO + 1, // 5x + 1
            5 * BASE_RATIO, // 5x
            IRebalanceRewardDistributor(address(0)),
            IRebalanceWhitelist(address(0)),
            "Strategy B",
            "STRAT-B"
        );

        address[] memory actors = _createActors(10);

        leverageManagerHandler = new LeverageManagerHandler(_leverageManager, strategies, actors);

        vm.label(address(leverageManagerHandler), "leverageManagerHandler");
    }

    function _initStrategy(
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio,
        uint256 targetCollateralRatio,
        IRebalanceRewardDistributor rebalanceRewardDistributor,
        IRebalanceWhitelist rebalanceWhitelist,
        string memory name,
        string memory symbol
    ) internal returns (IStrategy strategy) {
        MockERC20 collateralAsset = new MockERC20();
        MockERC20 debtAsset = new MockERC20();

        MockLendingAdapter lendingAdapter = new MockLendingAdapter(address(collateralAsset), address(debtAsset));

        ILeverageManager.StrategyConfig memory config = ILeverageManager.StrategyConfig({
            lendingAdapter: ILendingAdapter(address(lendingAdapter)),
            minCollateralRatio: minCollateralRatio,
            maxCollateralRatio: maxCollateralRatio,
            targetCollateralRatio: targetCollateralRatio,
            rebalanceRewardDistributor: rebalanceRewardDistributor,
            rebalanceWhitelist: rebalanceWhitelist
        });

        return leverageManager.createNewStrategy(config, name, symbol);
    }
}
