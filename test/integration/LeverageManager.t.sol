// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Dependency imports
import {Id, IMorpho, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {CollateralRatios, StrategyState, ExternalAction} from "src/types/DataTypes.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {Strategy} from "src/Strategy.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {MorphoLendingAdapterTest} from "./MorphoLendingAdapter.t.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IntegrationTestBase} from "./IntegrationTestBase.t.sol";

contract LeverageManagerTest is IntegrationTestBase {
    uint256 public BASE_RATIO;
    address public user = makeAddr("user");
    IStrategy public strategy;

    function setUp() public virtual override {
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        leverageManager = ILeverageManager(
            UnsafeUpgrades.deployUUPSProxy(
                leverageManagerImplementation,
                abi.encodeWithSelector(LeverageManager.initialize.selector, address(this))
            )
        );
        LeverageManager(address(leverageManager)).grantRole(keccak256("FEE_MANAGER_ROLE"), address(this));

        super.setUp();

        BASE_RATIO = LeverageManager(address(leverageManager)).BASE_RATIO();

        Strategy strategyImplementation = new Strategy();
        BeaconProxyFactory strategyFactory = new BeaconProxyFactory(address(strategyImplementation), address(this));

        leverageManager.setStrategyTokenFactory(address(strategyFactory));

        strategy = leverageManager.createNewStrategy(
            ILeverageManager.StrategyConfig({
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
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function testFork_deposit_NoFee() public {
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        uint256 debtToBorrow = 33922_924715; // 33922.924715

        deal(address(WETH), user, collateralToAdd);

        vm.startPrank(user);
        WETH.approve(address(leverageManager), collateralToAdd);
        leverageManager.deposit(strategy, equityInCollateralAsset, 0);
        vm.stopPrank();

        assertEq(strategy.balanceOf(user), equityInCollateralAsset);
        assertEq(WETH.balanceOf(user), 0);
        assertEq(USDC.balanceOf(user), debtToBorrow);

        assertEq(morphoLendingAdapter.getCollateral(), collateralToAdd);
        assertGe(morphoLendingAdapter.getDebt(), debtToBorrow);
        assertLe(morphoLendingAdapter.getDebt(), debtToBorrow + 1);

        // Validate that user never gets more equity than they deposited
        uint256 equityAfterDeposit = _convertToAssets(equityInCollateralAsset);
        assertGe(equityInCollateralAsset, equityAfterDeposit);
    }

    function testFork_deposit_WithFee() public {
        uint256 fee = 10_00; // 10%
        leverageManager.setStrategyActionFee(strategy, ExternalAction.Deposit, fee);

        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        // 10% fee
        assertEq(strategy.balanceOf(user), 9 ether);
        assertEq(strategy.balanceOf(user), strategy.totalSupply());
    }

    function testFork_deposit_PriceChangedBetweenDeposits_CollateralRatioDoesNotChange() public {
        leverageManager.setStrategyActionFee(strategy, ExternalAction.Deposit, 1); // 0.01%

        // Deposit again like in previous test
        uint256 equityInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 2 * equityInCollateralAsset;
        _deposit(user, equityInCollateralAsset, collateralToAdd);

        // Price doubles
        (,, address oracle,,) = morphoLendingAdapter.marketParams();
        uint256 currentPrice = IOracle(oracle).price();
        uint256 newPrice = currentPrice * 2;
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(newPrice));

        // Since price of ETH doubled current collateral ratio should be 4x and not 2x
        StrategyState memory stateBefore = _getStrategyState();
        assertGe(stateBefore.collateralRatio, 4 * BASE_RATIO - 1);
        assertLe(stateBefore.collateralRatio, 4 * BASE_RATIO);

        // Deposit based on what preview function says
        (uint256 collateral,,,) = leverageManager.previewDeposit(strategy, equityInCollateralAsset);
        uint256 shares = _deposit(user, equityInCollateralAsset, collateral);

        // Validate that user never gets more equity than they deposited
        uint256 equityAfterDeposit = _convertToAssets(shares);
        assertGe(equityInCollateralAsset, equityAfterDeposit);

        // Validate that user has no WETH left
        assertEq(WETH.balanceOf(user), 0);

        // Validate that collateral ratio did not change which means that new deposit follows current collateral ratio and not target
        // It is important that there can be rounding error but it should bring collateral ratio up not down
        StrategyState memory stateAfter = _getStrategyState();
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio + 1);

        // // Price goes down 3x
        newPrice /= 3;
        vm.mockCall(address(oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(newPrice));

        stateBefore = _getStrategyState();

        (collateral,,,) = leverageManager.previewDeposit(strategy, equityInCollateralAsset);
        shares = _deposit(user, equityInCollateralAsset, collateral);

        // Validate that user never gets more equity than they deposited
        equityAfterDeposit = _convertToAssets(shares);
        assertGe(equityInCollateralAsset, equityAfterDeposit);

        // Validate that collateral ratio did not change which means that new deposit follows current collateral ratio and not target
        stateAfter = _getStrategyState();
        assertEq(stateAfter.collateralRatio, stateBefore.collateralRatio);
    }

    function _deposit(address caller, uint256 equityInCollateralAsset, uint256 collateralToAdd)
        internal
        returns (uint256)
    {
        deal(address(WETH), caller, collateralToAdd);
        vm.startPrank(caller);
        WETH.approve(address(leverageManager), collateralToAdd);
        (,, uint256 shares,) = leverageManager.deposit(strategy, equityInCollateralAsset, 0);
        vm.stopPrank();

        return shares;
    }

    function _getStrategyState() internal view returns (StrategyState memory) {
        return LeverageManagerHarness(address(leverageManager)).exposed_getStrategyState(strategy);
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        return Math.mulDiv(
            shares,
            morphoLendingAdapter.getEquityInCollateralAsset() + 1,
            strategy.totalSupply() + 1,
            Math.Rounding.Floor
        );
    }
}
