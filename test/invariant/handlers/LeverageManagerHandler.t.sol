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
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {ActionData, StrategyState} from "src/types/DataTypes.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";

contract LeverageManagerHandler is Test {
    enum ActionType {
        // Invariants are checked before any calls are made as well, so we need a specific identifer for it for filtering
        Initial,
        Deposit,
        AddCollateral,
        RepayDebt,
        Withdraw
    }

    struct AddCollateralActionData {
        uint256 collateral;
    }

    struct DepositActionData {
        uint256 equityInCollateralAsset;
        ActionData preview;
    }

    struct RepayDebtActionData {
        uint256 debt;
    }

    struct WithdrawActionData {
        uint256 equityInCollateralAsset;
        ActionData preview;
    }

    struct StrategyStateData {
        IStrategy strategy;
        ActionType actionType;
        uint256 collateral;
        uint256 collateralInDebtAsset;
        uint256 debt;
        uint256 equityInDebtAsset;
        uint256 collateralRatio;
        uint256 totalSupply;
        bytes actionData;
    }

    uint256 public BASE_RATIO;

    LeverageManagerHarness public leverageManager;
    IStrategy[] public strategies;
    address[] public actors;

    address public currentActor;
    IStrategy public currentStrategy;

    StrategyStateData public strategyStateBefore;

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

    /// @dev This function is used to print the call summary to the console, useful for debugging runs on failure
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

        ActionData memory preview = leverageManager.previewDeposit(currentStrategy, equityForDeposit);

        _saveStrategyState(
            currentStrategy,
            ActionType.Deposit,
            abi.encode(DepositActionData({equityInCollateralAsset: equityForDeposit, preview: preview}))
        );

        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(currentStrategy);
        deal(address(collateralAsset), currentActor, type(uint256).max);
        collateralAsset.approve(address(leverageManager), type(uint256).max);
        leverageManager.deposit(currentStrategy, equityForDeposit, 0);
    }

    /// @dev Simulates someone adding collateral to the position held by the strategy directly, not through the LeverageManager.
    function addCollateral(uint256 seed) public useStrategy countCall("addCollateral") {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(currentStrategy)));
        uint256 collateral = lendingAdapter.getCollateral();
        IERC20 collateralAsset = lendingAdapter.collateralAsset();
        uint256 collateralToAdd = bound(seed, 0, type(uint128).max - collateral);

        _saveStrategyState(
            currentStrategy,
            ActionType.AddCollateral,
            abi.encode(AddCollateralActionData({collateral: collateralToAdd}))
        );

        deal(address(collateralAsset), address(this), collateralToAdd);
        collateralAsset.approve(address(lendingAdapter), collateralToAdd);
        lendingAdapter.addCollateral(collateralToAdd);
    }

    /// @dev Simulates someone repaying debt from the position held by the strategy directly, not through the LeverageManager.
    function repayDebt(uint256 seed) public useStrategy countCall("repayDebt") {
        MockLendingAdapter lendingAdapter =
            MockLendingAdapter(address(leverageManager.getStrategyLendingAdapter(currentStrategy)));
        uint256 debt = lendingAdapter.getDebt();
        IERC20 debtAsset = lendingAdapter.debtAsset();
        uint256 debtToRemove = bound(seed, 0, debt);

        _saveStrategyState(currentStrategy, ActionType.RepayDebt, abi.encode(RepayDebtActionData({debt: debtToRemove})));

        deal(address(debtAsset), address(this), debtToRemove);
        debtAsset.approve(address(lendingAdapter), debtToRemove);
        lendingAdapter.repay(debtToRemove);
    }

    function withdraw(uint256 seed) public useStrategy useActor countCall("withdraw") {
        uint256 equityForWithdraw = _boundEquityForWithdraw(currentStrategy, currentActor, seed);

        ActionData memory preview = leverageManager.previewWithdraw(currentStrategy, equityForWithdraw);

        _saveStrategyState(
            currentStrategy,
            ActionType.Withdraw,
            abi.encode(WithdrawActionData({equityInCollateralAsset: equityForWithdraw, preview: preview}))
        );

        IERC20 debtAsset = leverageManager.getStrategyDebtAsset(currentStrategy);
        deal(address(debtAsset), currentActor, type(uint256).max);
        debtAsset.approve(address(leverageManager), type(uint256).max);
        leverageManager.withdraw(currentStrategy, equityForWithdraw, currentStrategy.balanceOf(currentActor));
    }

    function convertToAssets(IStrategy strategy, uint256 shares) public view returns (uint256) {
        return Math.mulDiv(
            shares,
            leverageManager.getStrategyLendingAdapter(strategy).getEquityInCollateralAsset() + 1,
            strategy.totalSupply() + 1,
            Math.Rounding.Floor
        );
    }

    function getStrategyStateBefore() public view returns (StrategyStateData memory) {
        return strategyStateBefore;
    }

    function pickActor() public returns (address) {
        return actors[bound(vm.randomUint(), 0, actors.length - 1)];
    }

    function pickStrategy() public returns (IStrategy) {
        return strategies[bound(vm.randomUint(), 0, strategies.length - 1)];
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

    function _boundEquityForWithdraw(IStrategy strategy, address actor, uint256 seed) internal view returns (uint256) {
        uint256 shares = strategy.balanceOf(actor);
        uint256 maxEquity = convertToAssets(strategy, shares);

        // Divide max equity by a random number between 1 and 10 to split withdrawals up more among calls
        uint256 equityDivisor = bound(seed, 1, 10);
        return bound(seed, 0, maxEquity / equityDivisor);
    }

    function _saveStrategyState(IStrategy strategy, ActionType actionType, bytes memory actionData) internal {
        ILendingAdapter lendingAdapter = leverageManager.getStrategyLendingAdapter(strategy);

        uint256 collateralRatio = leverageManager.exposed_getStrategyState(strategy).collateralRatio;
        uint256 collateral = lendingAdapter.getCollateral();
        uint256 collateralInDebtAsset = lendingAdapter.convertCollateralToDebtAsset(collateral);
        uint256 debt = lendingAdapter.getDebt();
        uint256 totalSupply = strategy.totalSupply();

        strategyStateBefore = StrategyStateData({
            strategy: strategy,
            actionType: actionType,
            collateral: collateral,
            collateralInDebtAsset: collateralInDebtAsset,
            debt: debt,
            equityInDebtAsset: lendingAdapter.getEquityInDebtAsset(),
            collateralRatio: collateralRatio,
            totalSupply: totalSupply,
            actionData: actionData
        });
    }
}
