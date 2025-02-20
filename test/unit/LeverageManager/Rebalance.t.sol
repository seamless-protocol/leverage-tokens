// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {LeverageManagerBaseTest} from "test/unit/LeverageManager/LeverageManagerBase.t.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {MockRebalanceRewardDistributor} from "test/unit/mock/MockRebalanceRewardDistributor.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {RebalanceAction, ActionType, TokenTransfer, StrategyState} from "src/types/DataTypes.sol";

contract RebalanceTest is LeverageManagerBaseTest {
    ERC20Mock public WETH = new ERC20Mock();
    ERC20Mock public USDC = new ERC20Mock();

    MockRebalanceRewardDistributor public rewardDistributor = new MockRebalanceRewardDistributor();
    MockLendingAdapter public adapter;

    function setUp() public override {
        super.setUp();

        adapter = new MockLendingAdapter(address(WETH), address(USDC));

        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(adapter)),
                minCollateralRatio: 15 * _BASE_RATIO() / 10, // 1.5x leverage
                maxCollateralRatio: 25 * _BASE_RATIO() / 10, // 2.5x leverage
                targetCollateralRatio: 2 * _BASE_RATIO(), // 2x leverage
                collateralCap: type(uint256).max,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(rewardDistributor)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            address(WETH),
            address(USDC),
            "ETH Long 2x",
            "ETHL2x"
        );
    }

    function test_Rebalance_SimpleRebalanceSingleStrategy_Overcollateralized() public {
        adapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC
        adapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        adapter.mockDebt(5_000 ether); // 5,000 USDC

        // Current leverage is 4x and strategy needs to be rebalanced, current equity is 15,000 USDC
        uint256 amountToBorrow = 10_000 ether; // 10,000 USDC
        uint256 amountToSupply = 5 ether; // 5 ETH = 10,000 USDC

        WETH.mint(address(this), amountToSupply);

        // Rebalancer gives collateral that will be supplied
        TokenTransfer[] memory transfersIn = new TokenTransfer[](1);
        transfersIn[0] = TokenTransfer({token: address(WETH), amount: amountToSupply});

        // Rebalancer takes debt that will be borrowed and will swap it on his own
        TokenTransfer[] memory transfersOut = new TokenTransfer[](1);
        transfersOut[0] = TokenTransfer({token: address(USDC), amount: amountToBorrow});

        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: amountToSupply});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: amountToBorrow});

        WETH.approve(address(leverageManager), amountToSupply);
        leverageManager.rebalance(actions, transfersIn, transfersOut);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateralInDebtAsset, 30_000 ether); // 15 ETH = 30,000 USDC
        assertEq(state.debt, 15_000 ether); // 15,000 USDC
        assertEq(state.equity, 15_000 ether); // 15,000 USDC
        assertEq(state.collateralRatio, 2 * _BASE_RATIO()); // Back to 2x leverage
        assertEq(USDC.balanceOf(address(this)), amountToBorrow); // Rebalancer took debt
    }

    function test_Rebalance_SimpleRebalanceSingleStrategy_RebalancerTakesReward_Overcollateralized() public {
        adapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC
        adapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        adapter.mockDebt(5_000 ether); // 5,000 USDC

        // Current leverage is 4x and strategy needs to be rebalanced, current equity is 15,000 USDC
        uint256 amountToBorrow = 5_000 ether; // 5,000 USDC
        uint256 amountToSupply = 2.25 ether; // 2,25 ETH = 4500 USDC

        WETH.mint(address(this), amountToSupply);

        // Rebalancer gives collateral that will be supplied
        TokenTransfer[] memory transfersIn = new TokenTransfer[](1);
        transfersIn[0] = TokenTransfer({token: address(WETH), amount: amountToSupply});

        // Rebalancer takes debt that will be borrowed and will swap it on his own
        TokenTransfer[] memory transfersOut = new TokenTransfer[](1);
        transfersOut[0] = TokenTransfer({token: address(USDC), amount: amountToBorrow});

        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: amountToSupply});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: amountToBorrow});

        WETH.approve(address(leverageManager), amountToSupply);
        leverageManager.rebalance(actions, transfersIn, transfersOut);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateralInDebtAsset, 24_500 ether); // 12,25 ETH = 24,500 USDC
        assertEq(state.debt, 10_000 ether); // 10,000 USDC
        assertEq(state.equity, 14_500 ether); // 14,500 USDC, 10% reward
        assertEq(state.collateralRatio, 245 * _BASE_RATIO() / 100); // Back to 2.45x leverage which is better than 4x
        assertEq(USDC.balanceOf(address(this)), amountToBorrow); // Rebalancer took debt
    }

    function test_Rebalance_SimpleRebalanceSingleStrategy_RebalancerTakesReward_Undercollateralized() public {
        adapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC, mock ETH price
        adapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        adapter.mockDebt(15_000 ether); // 15,000 USDC

        // Current leverage is 1,333x and strategy needs to be rebalanced, current equity is 5,000 USDC
        uint256 amountToRepay = 10_000 ether; // 10,000 USDC
        uint256 amountToWithdraw = 5.5 ether; // 5,5 ETH = 11,000 USDC

        USDC.mint(address(this), amountToRepay);

        // Rebalancer gives debt that will be repaid
        TokenTransfer[] memory transfersIn = new TokenTransfer[](1);
        transfersIn[0] = TokenTransfer({token: address(USDC), amount: amountToRepay});

        // Rebalancer takes collateral that will be withdrawn
        TokenTransfer[] memory transfersOut = new TokenTransfer[](1);
        transfersOut[0] = TokenTransfer({token: address(WETH), amount: amountToWithdraw});

        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.Repay, amount: amountToRepay});
        actions[1] =
            RebalanceAction({strategy: strategy, actionType: ActionType.RemoveCollateral, amount: amountToWithdraw});

        USDC.approve(address(leverageManager), amountToRepay);
        leverageManager.rebalance(actions, transfersIn, transfersOut);

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);
        assertEq(state.collateralInDebtAsset, 9_000 ether); // 4,5 ETH = 9,000 USDC
        assertEq(state.debt, 5_000 ether); // 5,000 USDC
        assertEq(state.equity, 4_000 ether); // 4,500 USDC, 10% reward
        assertEq(state.collateralRatio, 180 * _BASE_RATIO() / 100); // Back to 1,8x leverage which is better than 1,333x
        assertEq(WETH.balanceOf(address(this)), amountToWithdraw); // Rebalancer took collateral
    }

    function test_Rebalance_MultipleStrategies_MoveFundsAcrossStrategies() public {
        IStrategy ethLong = strategy;
        MockLendingAdapter ethLongAdapter = adapter;
        MockLendingAdapter ethShortAdapter = new MockLendingAdapter(address(USDC), address(WETH));

        vm.startPrank(manager);
        IStrategy ethShort = leverageManager.createNewStrategy(
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(ethShortAdapter)),
                minCollateralRatio: 14 * _BASE_RATIO() / 10, // 2.5x leverage
                maxCollateralRatio: 16 * _BASE_RATIO() / 10, // 3.5x leverage
                targetCollateralRatio: 15 * _BASE_RATIO() / 10, // 3x leverage which means 2x price exposure
                collateralCap: type(uint256).max,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(rewardDistributor)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            "ETH Short 2x",
            "ETHS2x"
        );
        vm.stopPrank();

        ethLongAdapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC
        ethLongAdapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        ethLongAdapter.mockDebt(5_000 ether); // 5,000 USDC

        ethShortAdapter.mockConvertCollateralToDebtAssetExchangeRate(5_0000); // ETH = 2000 USDC => USDC = 0.0005 ETH
        ethShortAdapter.mockCollateral(15_000 ether); // 15,000 USDC
        ethShortAdapter.mockDebt(2.5 ether); // 2,5 ETH = 5,000 USDC

        // Both strategies are over-collateralized and need to be rebalanced
        // ETH long has current equity of 15,000 USDC
        // ETH short has current equity of 10,000 USDC
        // ETH long needs to borrow 10,000 USDC and supply 5 ETH
        // ETH short needs to borrow 7,5 ETH and supply 15,000 USDC

        uint256 amountToBorrowLong = 5_000 ether; // 5,000 USDC
        uint256 amountToSupplyLong = 2.25 ether; // 2,25 ETH = 4500 USDC

        uint256 amountToBorrowShort = 2.5 ether; // 2,5 ETH = 5000 USDC
        uint256 amountToSupplyShort = 4_500 ether; // 4,500 USDC

        RebalanceAction[] memory actions = new RebalanceAction[](4);
        actions[0] = RebalanceAction({strategy: ethShort, actionType: ActionType.Borrow, amount: amountToBorrowShort});
        actions[1] = RebalanceAction({strategy: ethLong, actionType: ActionType.Borrow, amount: amountToBorrowLong});
        actions[2] =
            RebalanceAction({strategy: ethShort, actionType: ActionType.AddCollateral, amount: amountToSupplyShort});
        actions[3] =
            RebalanceAction({strategy: ethLong, actionType: ActionType.AddCollateral, amount: amountToSupplyLong});

        uint256 usdcToTake = 500 ether; // 500 USDC
        uint256 wethToTake = 0.25 ether; // 0,25 ETH = 500 USDC

        TokenTransfer[] memory transfersOut = new TokenTransfer[](2);
        transfersOut[0] = TokenTransfer({token: address(WETH), amount: wethToTake});
        transfersOut[1] = TokenTransfer({token: address(USDC), amount: usdcToTake});

        leverageManager.rebalance(actions, new TokenTransfer[](0), transfersOut);

        StrategyState memory stateLong = leverageManager.exposed_getStrategyState(ethLong);
        assertEq(stateLong.collateralInDebtAsset, 24_500 ether);
        assertEq(stateLong.debt, 10_000 ether);
        assertEq(stateLong.equity, 14_500 ether);
        assertEq(stateLong.collateralRatio, 2_45 * _BASE_RATIO() / 100); // 2,45 leverage

        StrategyState memory stateShort = leverageManager.exposed_getStrategyState(ethShort);
        assertEq(stateShort.collateralInDebtAsset, 9.75 ether); // 9,75 ETH = 19,500 USDC
        assertEq(stateShort.debt, 5 ether); // 5,000 ETH = 10,000 USDC
        assertEq(stateShort.equity, 4.75 ether); // 4,750 ETH = 9,500 USDC
        assertEq(stateShort.collateralRatio, 1_95 * _BASE_RATIO() / 100); // 1,95 leverage

        assertEq(USDC.balanceOf(address(this)), usdcToTake);
        assertEq(WETH.balanceOf(address(this)), wethToTake);
    }

    function test_rebalance_RevertIf_EquityLossToBig() external {
        adapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC
        adapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        adapter.mockDebt(5_000 ether); // 5,000 USDC

        // Current leverage is 4x and strategy needs to be rebalanced, current equity is 15,000 USDC
        uint256 amountToBorrow = 10_000 ether; // 10,000 USDC
        uint256 amountToSupply = 4 ether; // 4 ETH = 8,000 USDC

        WETH.mint(address(this), amountToSupply);

        // Rebalancer gives collateral that will be supplied
        TokenTransfer[] memory transfersIn = new TokenTransfer[](1);
        transfersIn[0] = TokenTransfer({token: address(WETH), amount: amountToSupply});

        // Rebalancer takes debt that will be borrowed and will swap it on his own
        TokenTransfer[] memory transfersOut = new TokenTransfer[](1);
        transfersOut[0] = TokenTransfer({token: address(USDC), amount: amountToBorrow});

        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: amountToSupply});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: amountToBorrow});

        WETH.approve(address(leverageManager), amountToSupply);

        vm.expectRevert(ILeverageManager.EquityLossTooBig.selector);
        leverageManager.rebalance(actions, transfersIn, transfersOut);
    }

    function test_rebalance_RevertIf_CollateralRatioChangesDirection() external {
        adapter.mockConvertCollateralToDebtAssetExchangeRate(2_000_00000000); // ETH = 2000 USDC
        adapter.mockCollateral(10 ether); // 10 ETH = 20,000 USDC
        adapter.mockDebt(5_000 ether); // 5,000 USDC

        // Current leverage is 4x and strategy needs to be rebalanced, current equity is 15,000 USDC
        uint256 amountToBorrow = 11_000 ether; // 11,000 USDC
        uint256 amountToSupply = 5.5 ether; // 5,5 ETH = 11,000 USDC

        WETH.mint(address(this), amountToSupply);

        // Rebalancer gives collateral that will be supplied
        TokenTransfer[] memory transfersIn = new TokenTransfer[](1);
        transfersIn[0] = TokenTransfer({token: address(WETH), amount: amountToSupply});

        // Rebalancer takes debt that will be borrowed and will swap it on his own
        TokenTransfer[] memory transfersOut = new TokenTransfer[](1);
        transfersOut[0] = TokenTransfer({token: address(USDC), amount: amountToBorrow});

        RebalanceAction[] memory actions = new RebalanceAction[](2);
        actions[0] = RebalanceAction({strategy: strategy, actionType: ActionType.AddCollateral, amount: amountToSupply});
        actions[1] = RebalanceAction({strategy: strategy, actionType: ActionType.Borrow, amount: amountToBorrow});

        WETH.approve(address(leverageManager), amountToSupply);

        vm.expectRevert(ILeverageManager.ExposureDirectionChanged.selector);
        leverageManager.rebalance(actions, transfersIn, transfersOut);
    }
}
