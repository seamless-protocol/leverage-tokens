// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {StrategyState, RebalanceAction, ActionType, TokenTransfer} from "src/types/DataTypes.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBase} from "test/integration/LeverageManager/LeverageManagerBase.t.sol";
import {MockRebalanceRewardDistributor} from "test/unit/mock/MockRebalanceRewardDistributor.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";

contract RebalanceTest is LeverageManagerBase {
    int256 public constant MAX_PERCENTAGE = 100_00; // 100%

    Id public constant USDC_WETH_MARKET_ID = Id.wrap(0x3b3769cfca57be2eaed03fcc5299c25691b77781a1e124e7a8d520eb9a7eabb5);
    address public rebalancer = makeAddr("rebalancer");

    IStrategy ethLong2x;
    IStrategy ethShort2x;

    MorphoLendingAdapter ethLong2xAdapter;
    MorphoLendingAdapter ethShort2xAdapter;

    function setUp() public override {
        super.setUp();

        // Deploying simple reward distributor for now because more complex reward distributor will be tested separately
        // The same reward distributor can be used for multiple strategies because it is state-less
        MockRebalanceRewardDistributor mockRebalanceRewardDistributor = new MockRebalanceRewardDistributor();

        ethLong2xAdapter = MorphoLendingAdapter(
            morphoLendingAdapterFactory.createProxy(
                abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, WETH_USDC_MARKET_ID),
                bytes32(uint256(1))
            )
        );

        ethShort2xAdapter = MorphoLendingAdapter(
            morphoLendingAdapterFactory.createProxy(
                abi.encodeWithSelector(MorphoLendingAdapter.initialize.selector, USDC_WETH_MARKET_ID),
                bytes32(uint256(2))
            )
        );

        ethLong2x = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(ethLong2xAdapter)),
                minCollateralRatio: 18 * BASE_RATIO / 10, // 1.8x
                targetCollateralRatio: 2 * BASE_RATIO, // 2x
                maxCollateralRatio: 22 * BASE_RATIO / 10, // 2.2x
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(mockRebalanceRewardDistributor)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "Seamless ETH/USDC 2x leverage token",
            "ltETH/USDC-2x"
        );

        ethShort2x = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(ethShort2xAdapter)),
                minCollateralRatio: 13 * BASE_RATIO / 10, // 1.3x
                targetCollateralRatio: 15 * BASE_RATIO / 10, // 1.5x
                maxCollateralRatio: 2 * BASE_RATIO, // 2x
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(mockRebalanceRewardDistributor)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "Seamless USDC/ETH 2x leverage token",
            "ltUSDC/ETH-2x"
        );
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function test_rebalance_SingleStrategy_OverCollateralized() public {
        _depositEthLong2x();

        // After previous action we expect strategy to have 20 ETH collateral
        // We need to mock price change so strategy goes off balance
        // Price should change for 20% which means that collateral ratio is now going to be 2.4x
        // Price of ETH after this change should be 4070.750000000000000000000000
        _moveEthPrice(20_00);

        StrategyState memory stateBefore = _getStrategyState(ethLong2x);
        assertGe(stateBefore.collateralRatio, 24 * BASE_RATIO / 10 - 1);
        assertLe(stateBefore.collateralRatio, 24 * BASE_RATIO / 10);

        uint256 collateralBefore = ethLong2xAdapter.getCollateral();
        uint256 debtBefore = ethLong2xAdapter.getDebt();

        // At the moment we have the following state:
        // 20 ETH collateral = 81414.999999999999999999999992 USDC debt
        // 33922.92471591441746049801068 USDC debt is owed to the Morpho protocol

        // User rebalances the strategy but still leaves it out of bounds
        // User adds 1 ETH collateral and borrows 4100 USDC
        _rebalance(ethLong2x, 1e18, 0, 4100 * 1e6, 0);

        // Validate that ratio is better (leans towards 2x)
        StrategyState memory stateAfter = _getStrategyState(ethLong2x);
        assertLe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertGe(stateAfter.collateralRatio, 2 * BASE_RATIO);

        uint256 collateralAfter = ethLong2xAdapter.getCollateral();
        uint256 debtAfter = ethLong2xAdapter.getDebt();

        // Check that collateral and debt are changed properly
        assertEq(collateralAfter, collateralBefore + 1e18);
        assertEq(debtAfter, debtBefore + 4100 * 1e6);

        // Check that USDC is sent to rebalancer and that WETH is taken from him
        assertEq(USDC.balanceOf(rebalancer), 4100 * 1e6);
        assertEq(WETH.balanceOf(rebalancer), 0);
    }

    function test_rebalance_SingleStrategy_UnderCollateralized() public {
        _depositEthLong2x();

        // After previous action we expect strategy to have 20 ETH collateral
        // We need to mock price change so strategy goes off balance
        // Price should change for 20% downwards which means that collateral ratio is now going to be 1.6x
        // Price of ETH after this change should be 2728.194981060953630732673600
        _moveEthPrice(-20_00);

        StrategyState memory stateBefore = _getStrategyState(ethLong2x);
        assertGe(stateBefore.collateralRatio, 16 * BASE_RATIO / 10 - 1);
        assertLe(stateBefore.collateralRatio, 16 * BASE_RATIO / 10);

        uint256 collateralBefore = ethLong2xAdapter.getCollateral();
        uint256 debtBefore = ethLong2xAdapter.getDebt();

        // User repays 2800 USDC and removes 1 ETH collateral
        _rebalance(ethLong2x, 0, 1e18, 0, 2800 * 1e6);

        // Validate that ratio is better (leans towards 2x)
        StrategyState memory stateAfter = _getStrategyState(ethLong2x);
        assertGe(stateAfter.collateralRatio, stateBefore.collateralRatio);
        assertLe(stateAfter.collateralRatio, 2 * BASE_RATIO);

        uint256 collateralAfter = ethLong2xAdapter.getCollateral();
        uint256 debtAfter = ethLong2xAdapter.getDebt();

        // Check that collateral and debt are changed properly
        assertEq(collateralAfter, collateralBefore - 1e18);
        assertEq(debtAfter, debtBefore - 2800 * 1e6);

        // Check that USDC is sent to rebalancer and that WETH is taken from him
        assertEq(USDC.balanceOf(rebalancer), 0);
        assertEq(WETH.balanceOf(rebalancer), 1e18);
    }

    function test_rebalance_RevertIf_EquityLossTooBig() public {
        _depositEthLong2x();

        // Move price of ETH 20% upwards
        _moveEthPrice(20_00);

        (RebalanceAction[] memory actions, TokenTransfer[] memory transfersIn, TokenTransfer[] memory transfersOut) =
            _prepareForRebalance(ethLong2x, 1e18, 0, 5000 * 1e6, 0);

        vm.prank(rebalancer);
        vm.expectRevert(ILeverageManager.EquityLossTooBig.selector);
        leverageManager.rebalance(actions, transfersIn, transfersOut);
    }

    /// @dev In this block price on oracle 3392.292471591441746049801068
    function test_rebalance_RevertIf_ExposureDirectionChanged() public {
        _depositEthLong2x();

        // Move price of ETH 20% downwards
        _moveEthPrice(-20_00);

        // User comes and rebalances it in a way that he only adds collateral so strategy becomes over-collateralized
        (RebalanceAction[] memory actions, TokenTransfer[] memory transfersIn, TokenTransfer[] memory transfersOut) =
            _prepareForRebalance(ethLong2x, 10 * 1e18, 0, 0, 0);

        vm.prank(rebalancer);
        vm.expectRevert(ILeverageManager.ExposureDirectionChanged.selector);
        leverageManager.rebalance(actions, transfersIn, transfersOut);
    }

    /// @dev In this test amounts are smaller because there is not enough liquidity on Morpho to borrow for short strategy
    function test_rebalance_MoveFundsAcrossStrategies() public {
        _depositEthLong2x();

        // Because USDC/ETH market utilization is 100% in this block (everything is borrowed) we need to deposit some assets for borrowing
        // Random user puts 1000 WETH in USDC/WETH market
        _supplyWETHForETHShortStrategy();

        _depositEthShort2x();

        _moveEthPrice(20_00);

        // ETH short strategy is now under-collateralized and we are going to gift it 30_000 USDC to simulate over-collateralized state
        _giftUSDCToETHShortStrategy();

        // Double check that both strategies are over-collateralized
        StrategyState memory ethLongStateBefore = _getStrategyState(ethLong2x);
        assertGe(ethLongStateBefore.collateralRatio, 2 * BASE_RATIO);

        StrategyState memory ethShortStateBefore = _getStrategyState(ethShort2x);
        assertGe(ethShortStateBefore.collateralRatio, 15 * BASE_RATIO / 10);

        // Prepare rebalance parameters
        uint256 ethShortDebtToBorrow = 3 * 1e18;
        uint256 ethLongCollateralToAdd = 2.9 * 1e18;
        uint256 ethLongDebtToBorrow = 12_000 * 1e6;
        uint256 ethShortCollateralToAdd = 11_500 * 1e6;

        RebalanceAction[] memory actions = new RebalanceAction[](4);
        actions[0] =
            RebalanceAction({strategy: ethShort2x, actionType: ActionType.Borrow, amount: ethShortDebtToBorrow});
        actions[1] =
            RebalanceAction({strategy: ethLong2x, actionType: ActionType.AddCollateral, amount: ethLongCollateralToAdd});
        actions[2] = RebalanceAction({strategy: ethLong2x, actionType: ActionType.Borrow, amount: ethLongDebtToBorrow});
        actions[3] = RebalanceAction({
            strategy: ethShort2x,
            actionType: ActionType.AddCollateral,
            amount: ethShortCollateralToAdd
        });

        TokenTransfer[] memory transfersIn = new TokenTransfer[](0);
        TokenTransfer[] memory transfersOut = new TokenTransfer[](2);
        transfersOut[0] = TokenTransfer({token: address(WETH), amount: 0.1 * 1e18});
        transfersOut[1] = TokenTransfer({token: address(USDC), amount: 500 * 1e6});

        vm.prank(rebalancer);
        leverageManager.rebalance(actions, transfersIn, transfersOut);

        // Check that rebalancer has received the tokens as reward
        assertEq(WETH.balanceOf(rebalancer), 0.1 * 1e18);
        assertEq(USDC.balanceOf(rebalancer), 500 * 1e6);

        // Check that strategies are in better state
        StrategyState memory ethLongStateAfter = _getStrategyState(ethLong2x);
        assertGe(ethLongStateAfter.collateralRatio, 2 * BASE_RATIO);
        assertLe(ethLongStateAfter.collateralRatio, ethLongStateBefore.collateralRatio);

        StrategyState memory ethShortStateAfter = _getStrategyState(ethShort2x);
        assertGe(ethShortStateAfter.collateralRatio, 15 * BASE_RATIO / 10);
        assertLe(ethShortStateAfter.collateralRatio, ethShortStateBefore.collateralRatio);
    }

    struct RebalanceData {
        uint256 collateralToAdd;
        uint256 collateralToRemove;
        uint256 debtToBorrow;
        uint256 debtToRepay;
    }

    /// @notice Prepares rebalance parameters and executes rebalance
    /// @param strategy Strategy to rebalance
    /// @param collToAdd Amount of collateral to add
    /// @param collToTake Amount of collateral to remove
    /// @param debtToBorrow Amount of debt to borrow
    /// @param debtToRepay Amount of debt to repay
    function _rebalance(
        IStrategy strategy,
        uint256 collToAdd,
        uint256 collToTake,
        uint256 debtToBorrow,
        uint256 debtToRepay
    ) internal {
        (RebalanceAction[] memory actions, TokenTransfer[] memory transfersIn, TokenTransfer[] memory transfersOut) =
            _prepareForRebalance(strategy, collToAdd, collToTake, debtToBorrow, debtToRepay);

        vm.prank(rebalancer);
        leverageManager.rebalance(actions, transfersIn, transfersOut);
    }

    /// @notice Prepares the state for the rebalance which means prepares the parameters for function call but also mint tokens to rebalancer
    /// @param strategy Strategy to rebalance
    /// @param collToAdd Amount of collateral to add
    /// @param collToTake Amount of collateral to remove
    /// @param debtToBorrow Amount of debt to borrow
    /// @param debtToRepay Amount of debt to repay
    /// @return actions Actions to execute
    /// @return transfersIn Transfers in tokens parameters for function call
    /// @return transfersOut Transfers out tokens parameters for function call
    function _prepareForRebalance(
        IStrategy strategy,
        uint256 collToAdd,
        uint256 collToTake,
        uint256 debtToBorrow,
        uint256 debtToRepay
    )
        internal
        returns (
            RebalanceAction[] memory actions,
            TokenTransfer[] memory transfersIn,
            TokenTransfer[] memory transfersOut
        )
    {
        actions = new RebalanceAction[](4);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: collToAdd});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Repay, amount: debtToRepay});
        actions[2] = RebalanceAction({strategy: strategy, actionType: ActionType.RemoveCollateral, amount: collToTake});
        actions[3] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: debtToBorrow});

        address collateralToken = address(leverageManager.getStrategyCollateralAsset(strategy));
        address debtToken = address(leverageManager.getStrategyDebtAsset(strategy));

        // Give collateral token to add collateral and give debt token to repay debt
        transfersIn = new TokenTransfer[](2);
        transfersIn[0] = TokenTransfer({token: collateralToken, amount: collToAdd});
        transfersIn[1] = TokenTransfer({token: debtToken, amount: debtToRepay});

        transfersOut = new TokenTransfer[](2);
        transfersOut[0] = TokenTransfer({token: collateralToken, amount: collToTake});
        transfersOut[1] = TokenTransfer({token: debtToken, amount: debtToBorrow});

        // Mint collateral token to add collateral and debt token to repay debt
        deal(address(collateralToken), rebalancer, collToAdd);
        deal(address(debtToken), rebalancer, debtToRepay);

        vm.startPrank(rebalancer);

        // Approve collateral token to add collateral and debt token to repay debt
        IERC20(collateralToken).approve(address(leverageManager), collToAdd);
        IERC20(debtToken).approve(address(leverageManager), debtToRepay);

        vm.stopPrank();

        return (actions, transfersIn, transfersOut);
    }

    /// @dev Moves price of ETH for given percentage, if percentage is negative it moves price of ETH down
    function _moveEthPrice(int256 percentage) internal {
        // Move price on ETH long
        (,, address ethLongOracle,,) = ethLong2xAdapter.marketParams();
        uint256 currentPrice = IOracle(ethLongOracle).price();
        int256 priceChange = int256(currentPrice) * percentage / MAX_PERCENTAGE;
        uint256 newPrice = uint256(int256(currentPrice) + priceChange);
        vm.mockCall(address(ethLongOracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(newPrice));

        // Move price in different direction on ETH short
        (,, address ethShortOracle,,) = ethShort2xAdapter.marketParams();
        currentPrice = IOracle(ethShortOracle).price();
        priceChange = int256(currentPrice) * percentage / MAX_PERCENTAGE;
        newPrice = uint256(int256(currentPrice) - priceChange);
        vm.mockCall(address(ethShortOracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(newPrice));
    }

    function _supplyWETHForETHShortStrategy() internal {
        deal(address(WETH), address(this), 1000 * 1e18);
        IMorpho morpho = IMorpho(ethShort2xAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            ethShort2xAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        WETH.approve(address(morpho), 1000 * 1e18);
        morpho.supply(marketParams, 1000 * 1e18, 0, address(this), new bytes(0));
    }

    function _giftUSDCToETHShortStrategy() internal {
        deal(address(USDC), address(this), 150_000 * 1e6);
        IMorpho morpho = IMorpho(ethShort2xAdapter.morpho());

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            ethShort2xAdapter.marketParams();
        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        USDC.approve(address(morpho), 150_000 * 1e6);
        morpho.supplyCollateral(marketParams, 150_000 * 1e6, address(ethShort2xAdapter), new bytes(0));
    }

    /// @dev Performs initial deposit into ETH long strategy, amount is not important but it is important to gain some collateral and debt
    function _depositEthLong2x() internal {
        uint256 equityToDeposit = 10 ether;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(ethLong2x, equityToDeposit);
        _deposit(ethLong2x, user, equityToDeposit, collateralToAdd);
    }

    /// @dev Performs initial deposit into ETH short strategy, amount is not important but it is important to gain some collateral and debt
    function _depositEthShort2x() internal {
        uint256 equityToDeposit = 30_000 * 1e6;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(ethShort2x, equityToDeposit);
        _deposit(ethShort2x, user, equityToDeposit, collateralToAdd);
    }

    function _deposit(IStrategy _strategy, address _caller, uint256 _equityInCollateralAsset, uint256 _collateralToAdd)
        internal
        returns (uint256)
    {
        IERC20 collateralAsset = leverageManager.getStrategyCollateralAsset(_strategy);
        deal(address(collateralAsset), _caller, _collateralToAdd);

        vm.startPrank(_caller);
        collateralAsset.approve(address(leverageManager), _collateralToAdd);
        (,, uint256 shares,) = leverageManager.deposit(_strategy, _equityInCollateralAsset, 0);
        vm.stopPrank();

        return shares;
    }

    function _getStrategyState(IStrategy strategy) internal view returns (StrategyState memory) {
        return LeverageManagerHarness(address(leverageManager)).exposed_getStrategyState(strategy);
    }
}
