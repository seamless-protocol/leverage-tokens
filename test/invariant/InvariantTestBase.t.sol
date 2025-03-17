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

abstract contract InvariantTestBase is Test {
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

    function _createActors(uint256 numActors) internal returns (address[] memory) {
        address[] memory actors = new address[](numActors);
        for (uint256 i = 0; i < numActors; i++) {
            actors[i] = makeAddr(string.concat("actor-", Strings.toString(i)));
        }
        return actors;
    }

    function _fuzzedSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = LeverageManagerHandler.deposit.selector;
        selectors[1] = LeverageManagerHandler.withdraw.selector;
        selectors[2] = LeverageManagerHandler.addCollateral.selector;
        selectors[3] = LeverageManagerHandler.repayDebt.selector;
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

    /// @dev The allowed slippage in collateral ratio of the strategy after a deposit should scale with the size of the
    /// initial debt in the strategy, as smaller strategies may incur a higher collateral ratio delta after the
    /// deposit due to rounding.
    ///
    /// For example, if the initial collateral is 3 and the initial debt is 1 (with collateral and debt normalized) then the
    /// collateral ratio is 300000000, with 2 shares total supply. If a deposit of 1 equity is made, then the required collateral
    /// is 2 and the required debt is 0, so the resulting collateral is 5 and the debt is 1:
    ///
    ///    sharesMinted = convertToShares(1) = equityToAdd * (existingSharesTotalSupply + offset) / (existingEquity + offset) = 1 * 3 / 3 = 1
    ///    collateralToAdd = existingCollateral * sharesMinted / sharesTotalSupply = 3 * 1 / 2 = 2 (1.5 rounded up)
    ///    debtToBorrow = existingDebt * sharesMinted / sharesTotalSupply = 1 * 1 / 2 = 0 (0.5 rounded down)
    ///
    /// The resulting collateral ratio is 500000000, which is a ~+66.67% change from the initial collateral ratio.
    ///
    /// As the intial debt scales up in size, the allowed slippage should scale down as more precision can be achieved
    /// for the collateral ratio:
    ///    initialDebt < 100: 1e18 (100% slippage)
    ///    initialDebt < 1000: 0.1e18 (10% slippage)
    ///    initialDebt < 10000: 0.01e18 (1% slippage)
    ///    initialDebt < 100000: 0.001e18 (0.1% slippage)
    ///    initialDebt < 1000000: 0.0001e18 (0.01% slippage)
    ///    initialDebt < 10000000: 0.00001e18 (0.001% slippage)
    ///    initialDebt < 100000000: 0.000001e18 (0.0001% slippage)
    ///    initialDebt < 1000000000: 0.0000001e18 (0.00001% slippage)
    ///    initialDebt >= 1000000000: 0.00000001e18 (0.000001% slippage)
    ///
    /// Note: We can at minimum support up to 0.00000001e18 (0.000001% slippage) due to the base collateral ratio
    ///       being 1e8
    function _getAllowedCollateralRatioSlippage(uint256 initialDebt)
        internal
        pure
        returns (uint256 allowedSlippagePercentage)
    {
        if (initialDebt == 0) {
            return 1e18;
        }

        uint256 i = Math.log10(initialDebt);

        // This is the minimum slippage that we can support due to the precision of the collateral ratio being
        // 1e8 (1e18 / 1e8 = 1e10 = 0.00000001e18)
        if (i > 8) return 0.00000001e18;

        // If i <= 1, that means initialDebt < 100, thus slippage = 1e18
        // Otherwise slippage = 1e18 / (10^(i - 1))
        return (i <= 1) ? 1e18 : (1e18 / (10 ** (i - 1)));
    }
}
