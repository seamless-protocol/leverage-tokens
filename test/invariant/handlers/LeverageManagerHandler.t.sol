// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

// Dependency imports
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ActionData, StrategyState} from "src/types/DataTypes.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";

contract LeverageManagerHandler is Test {
    uint256 public BASE_RATIO;

    LeverageManagerHarness public leverageManager;
    IStrategy[] public strategies;
    address[] public actors;

    address public currentActor;
    IStrategy public currentStrategy;

    uint256 public totalCalls;
    mapping(string => uint256) public calls;

    modifier countCall(string memory key_) {
        totalCalls++;
        calls[key_]++;
        _;
    }

    modifier useActor() {
        currentActor = pickActor();
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useStrategy() {
        currentStrategy = pickStrategy();
        _;
    }

    constructor(LeverageManagerHarness _leverageManager, IStrategy[] memory _strategies, address[] memory _actors) {
        leverageManager = _leverageManager;
        strategies = _strategies;
        actors = _actors;

        BASE_RATIO = leverageManager.BASE_RATIO();

        vm.label(address(leverageManager), "leverageManager");

        for (uint256 i = 0; i < strategies.length; i++) {
            vm.label(
                address(strategies[i]),
                string.concat("strategy-", Strings.toHexString(uint256(uint160(address(strategies[i]))), 20))
            );
        }
    }

    /// @dev This function is used to print the call summary to the console, useful for debugging
    function callSummary() public view virtual {
        console2.log("CALL SUMMARY");
        console2.log("----------------------------------------------------------------------------");
        console2.log("deposit:", calls["deposit"]);
        console2.log("addCollateral:", calls["addCollateral"]);
        console2.log("repayDebt:", calls["repayDebt"]);
        console2.log("----------------------------------------------------------------------------");
        console2.log("Total: ", totalCalls);
    }

    function deposit(uint256 seed) public useStrategy useActor countCall("deposit") {
        uint256 equityForDeposit = _boundEquityForDeposit(currentStrategy, seed);

        StrategyState memory stateBefore = leverageManager.exposed_getStrategyState(currentStrategy);
        uint256 strategyTotalSupplyBefore = currentStrategy.totalSupply();

        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(currentStrategy);
        deal(address(collateralAsset), currentActor, type(uint256).max);
        collateralAsset.approve(address(leverageManager), type(uint256).max);
        leverageManager.deposit(currentStrategy, equityForDeposit, 0);

        _assertDepositInvariants(currentStrategy, stateBefore, strategyTotalSupplyBefore, equityForDeposit);
    }

    /// @dev Simulates someone adding collateral to the position held by the strategy directly, not through the LeverageManager.
    function addCollateral(uint256 seed) public useStrategy countCall("addCollateral") {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(currentStrategy)));
        uint256 collateral = lendingAdapter.getCollateral();
        IERC20 collateralAsset = lendingAdapter.collateralAsset();

        StrategyState memory stateBefore = leverageManager.exposed_getStrategyState(currentStrategy);

        uint256 collateralToAdd = bound(seed, 0, type(uint128).max - collateral);
        deal(address(collateralAsset), address(this), collateralToAdd);
        collateralAsset.approve(address(lendingAdapter), collateralToAdd);
        lendingAdapter.addCollateral(collateralToAdd);

        _assertAddCollateralInvariants(currentStrategy, stateBefore, collateralToAdd);
    }

    /// @dev Simulates someone repaying debt from the position held by the strategy directly, not through the LeverageManager.
    function repayDebt(uint256 seed) public useStrategy countCall("repayDebt") {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(currentStrategy)));
        uint256 debt = lendingAdapter.getDebt();
        IERC20 debtAsset = lendingAdapter.debtAsset();

        StrategyState memory stateBefore = leverageManager.exposed_getStrategyState(currentStrategy);

        uint256 debtToRemove = bound(seed, 0, debt);
        deal(address(debtAsset), address(this), debtToRemove);
        debtAsset.approve(address(lendingAdapter), debtToRemove);
        lendingAdapter.repay(debtToRemove);

        _assertRepayDebtInvariants(currentStrategy, stateBefore, debtToRemove);
    }

    function pickActor() public returns (address) {
        return actors[bound(vm.randomUint(), 0, actors.length - 1)];
    }

    function pickStrategy() public returns (IStrategy) {
        return strategies[bound(vm.randomUint(), 0, strategies.length - 1)];
    }

    function _assertAddCollateralInvariants(
        IStrategy strategy,
        StrategyState memory stateBefore,
        uint256 collateralAdded
    ) internal view {
        if (collateralAdded > 0) {
            StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(strategy);
            assertGt(
                stateAfter.collateralInDebtAsset,
                stateBefore.collateralInDebtAsset,
                "Invariant Violated: Collateral after adding collateral must be greater than the collateral before adding collateral."
            );
            assertGe(
                stateAfter.collateralInDebtAsset,
                stateBefore.collateralInDebtAsset,
                "Invariant Violated: Collateral in debt asset after adding collateral must be greater than or equal to the collateral in debt asset before adding collateral."
            );
        }
    }

    function _assertDepositInvariants(
        IStrategy strategy,
        StrategyState memory stateBefore,
        uint256 strategyTotalSupplyBefore,
        uint256 equityDeposited
    ) internal view {
        StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(strategy);

        // Empty strategy
        if (stateBefore.collateralInDebtAsset == 0 && stateBefore.debt == 0 && strategyTotalSupplyBefore == 0) {
            assertEq(
                stateBefore.collateralRatio,
                type(uint256).max,
                "Invariant Violated: Collateral ratio before deposit must be type(uint256).max in an empty strategy."
            );

            if (equityDeposited != 0) {
                // For an empty strategy, the debt amount is calculated as the difference between:
                // 1. The required collateral (determined using target ratio and the amount of equity to deposit)
                // 2. The equity being deposited
                // Thus, the precision of the resulting collateral ratio is higher as the amount of equity increases, and
                // lower as the amount of equity decreases.
                // For example:
                //     collateral and debt are 1:1
                //     targetCollateralRatio = 5e8
                //     equityDeposited = 583
                //     collateralRequiredForDeposit = 583 * 5e8 / (5e8 - 1e8) = 728.75 (729 rounded up)
                //     debtRequiredForDeposit = 729 - 583 = 146
                //     collateralRatioAfterDeposit = 729 / 146 = 4.9931506849 (not the target 5e8)
                assertApproxEqRel(
                    stateAfter.collateralRatio,
                    leverageManager.getStrategyTargetCollateralRatio(currentStrategy),
                    _getAllowedCollateralRatioSlippage(equityDeposited),
                    "Invariant Violated: Collateral ratio after deposit must be equal to the target collateral ratio, within the allowed collateral ratio slippage, if the strategy was initially empty."
                );
            } else {
                assertEq(
                    stateAfter.collateralRatio,
                    type(uint256).max,
                    "Invariant Violated: Collateral ratio after deposit must be type(uint256).max if no equity was deposited into an empty strategy."
                );
            }
        }
        // Strategy with 0 shares but non-zero collateral and debt
        else if (strategyTotalSupplyBefore == 0 && stateBefore.debt != 0 && stateBefore.collateralInDebtAsset != 0) {
            // It's possible that the strategy has no shares but has non-zero collateral and debt due to actors adding
            // collateral to the underlying position held by the strategy (directly, not through LeverageManager.deposit) before any shares are minted.
            // There can be debt because minShares is set to 0 in this function, so a depositor can add collateral and debt without receiving any shares.
            assertLe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after deposit must be less than or equal to the initial collateral ratio if the strategy has no shares but has non-zero collateral and debt."
            );
        }
        // Strategy with 0 debt but non-zero collateral
        else if (stateBefore.collateralInDebtAsset != 0 && stateBefore.debt == 0) {
            assertEq(
                stateBefore.collateralRatio,
                type(uint256).max,
                "Invariant Violated: Collateral ratio before deposit must be type(uint256).max if the strategy has non-zero collateral and zero debt."
            );
            assertGe(
                stateAfter.collateralRatio,
                leverageManager.getStrategyTargetCollateralRatio(currentStrategy),
                "Invariant Violated: Collateral ratio after deposit must be greater than or equal to the target collateral ratio if the strategy initially had non-zero collateral and zero debt."
            );
        } else {
            assertGe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after deposit must be greater than or equal to the initial collateral ratio."
            );
            assertApproxEqRel(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                _getAllowedCollateralRatioSlippage(stateBefore.debt),
                "Invariant Violated: Collateral ratio after deposit must be equal to the initial collateral ratio, within the allowed collateral ratio slippage."
            );
        }
    }

    function _assertRepayDebtInvariants(IStrategy strategy, StrategyState memory stateBefore, uint256 debtRemoved)
        internal
        view
    {
        if (debtRemoved > 0) {
            StrategyState memory stateAfter = leverageManager.exposed_getStrategyState(strategy);
            assertLt(
                stateAfter.debt,
                stateBefore.debt,
                "Invariant Violated: Debt after repaying debt must be less than the debt before repaying debt."
            );
            assertGe(
                stateAfter.collateralRatio,
                stateBefore.collateralRatio,
                "Invariant Violated: Collateral ratio after repaying debt must be greater than or equal to the collateral ratio before repaying debt."
            );
        }
    }

    /// @dev Bounds the amount of equity to deposit based on the maximum collateral and debt that can be added to a strategy
    ///      due to overflow limits
    function _boundEquityForDeposit(IStrategy strategy, uint256 seed) internal view returns (uint256) {
        StrategyState memory stateBefore = leverageManager.exposed_getStrategyState(strategy);

        // The maximum amount of collateral that can be added to a strategy using Morpho is type(uint128).max
        uint256 maxCollateralAmount = type(uint128).max
            - leverageManager.getStrategyLendingAdapter(strategy).convertDebtToCollateralAsset(
                stateBefore.collateralInDebtAsset
            );
        // Bound the amount of equity to deposit based on the maximum collateral that can be added
        bool shouldFollowTargetRatio = strategy.totalSupply() == 0 || stateBefore.debt == 0;
        uint256 collateralRatioForDeposit = shouldFollowTargetRatio
            ? leverageManager.getStrategyTargetCollateralRatio(strategy)
            : stateBefore.collateralRatio;
        uint256 maxEquity = Math.mulDiv(
            maxCollateralAmount, collateralRatioForDeposit - BASE_RATIO, collateralRatioForDeposit, Math.Rounding.Floor
        );

        // Divide max equity by a random number between 2 and 100000 to split deposits up more among calls
        uint256 equityDivisor = bound(seed, 2, 100000);
        return bound(seed, 0, maxEquity / equityDivisor);
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

    function _randomAddress() internal returns (address payable) {
        return payable(vm.randomAddress());
    }
}
