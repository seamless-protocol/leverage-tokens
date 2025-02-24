// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.t.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {Strategy} from "src/Strategy.sol";
import {MockERC20} from "test/unit/mock/MockERC20.sol";
import {MockLendingAdapter} from "test/unit/mock/MockLendingAdapter.sol";
import {ExternalAction} from "src/types/DataTypes.sol";

contract LeverageManagerBaseTest is FeeManagerBaseTest {
    IStrategy public strategy;
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");

    MockERC20 public collateralToken = new MockERC20();
    MockERC20 public debtToken = new MockERC20();

    MockLendingAdapter public lendingAdapter;

    address public strategyTokenImplementation;
    BeaconProxyFactory public strategyTokenFactory;
    LeverageManagerHarness public leverageManager;

    function setUp() public virtual override {
        strategyTokenImplementation = address(new Strategy());
        strategyTokenFactory = new BeaconProxyFactory(strategyTokenImplementation, address(this));

        lendingAdapter = new MockLendingAdapter(address(collateralToken), address(debtToken));

        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
        );

        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
        leverageManager.setStrategyTokenFactory(address(strategyTokenFactory));
        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);
        feeManager = FeeManagerHarness(address(leverageManager));
        vm.stopPrank();
    }

    function test_setUp() public view virtual override {
        bytes32 expectedSlot = keccak256(
            abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)
        ) & ~bytes32(uint256(0xff));

        assertTrue(leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), defaultAdmin));
        assertEq(leverageManager.exposed_leverageManager_layoutSlot(), expectedSlot);
    }

    function _BASE_RATIO() internal view returns (uint256) {
        return leverageManager.BASE_RATIO();
    }

    function _DECIMALS_OFFSET() internal view returns (uint256) {
        return leverageManager.DECIMALS_OFFSET();
    }

    function _getLendingAdapter() internal view returns (ILendingAdapter) {
        return leverageManager.getStrategyLendingAdapter(strategy);
    }

    function _createDummyStrategy() internal {
        strategy = IStrategy(
            _createNewStrategy(
                manager,
                Storage.StrategyConfig({
                    lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                    minCollateralRatio: _BASE_RATIO(),
                    maxCollateralRatio: _BASE_RATIO() + 2,
                    targetCollateralRatio: _BASE_RATIO() + 1,
                    collateralCap: type(uint256).max,
                    rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                    rebalanceWhitelist: IRebalanceWhitelist(address(0))
                }),
                address(0),
                address(0),
                "dummy name",
                "dummy symbol"
            )
        );
    }

    function _createNewStrategy(
        address caller,
        Storage.StrategyConfig memory config,
        address collateralAsset,
        address debtAsset,
        string memory name,
        string memory symbol
    ) internal returns (IStrategy) {
        vm.mockCall(
            address(config.lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getCollateralAsset.selector),
            abi.encode(IERC20(collateralAsset))
        );
        vm.mockCall(
            address(config.lendingAdapter),
            abi.encodeWithSelector(ILendingAdapter.getDebtAsset.selector),
            abi.encode(IERC20(debtAsset))
        );

        vm.startPrank(caller);
        strategy = leverageManager.createNewStrategy(config, name, symbol);
        vm.stopPrank();

        return strategy;
    }

    function _setStrategyCollateralRatios(address caller, CollateralRatios memory ratios) internal {
        vm.prank(caller);
        leverageManager.setStrategyCollateralRatios(strategy, ratios);
    }

    function _setStrategyRebalanceRewardDistributor(address caller, IRebalanceRewardDistributor distributor) internal {
        vm.prank(caller);
        leverageManager.setStrategyRebalanceRewardDistributor(strategy, distributor);
    }

    function _mintShares(address recipient, uint256 amount) internal {
        vm.prank(address(leverageManager));
        strategy.mint(recipient, amount);
    }

    struct CalculateDebtAndSharesState {
        uint256 targetRatio;
        uint128 strategyCollateral;
        uint128 depositAmount;
        uint128 depositAmountInDebtAsset;
        uint128 totalEquity;
        uint128 strategyTotalShares;
    }

    function _mockState_CalculateDebtAndShares(CalculateDebtAndSharesState memory state) internal {
        _mockState_ConvertToEquity(
            ConvertToSharesState({totalEquity: state.totalEquity, sharesTotalSupply: state.strategyTotalShares})
        );

        _mockStrategyCollateral(state.strategyCollateral);
        _mockConvertCollateral(state.depositAmount, state.depositAmountInDebtAsset);
        _setStrategyCollateralRatios(
            CollateralRatios({
                minCollateralRatio: 0,
                targetCollateralRatio: state.targetRatio,
                maxCollateralRatio: type(uint256).max
            })
        );
    }

    function _mockStrategyCollateral(uint256 collateral) internal {
        vm.mockCall(
            address(_getLendingAdapter()),
            abi.encodeWithSelector(ILendingAdapter.getCollateral.selector),
            abi.encode(collateral)
        );
    }

    struct ConvertToSharesState {
        uint256 totalEquity;
        uint256 sharesTotalSupply;
    }

    function _mockState_ConvertToShares(ConvertToSharesState memory state) internal {
        _mintShares(address(1), state.sharesTotalSupply);
        _mockStrategyTotalEquityInCollateralAsset(state.totalEquity);
    }

    function _mockState_ConvertToEquity(ConvertToSharesState memory state) internal {
        _mintShares(address(1), state.sharesTotalSupply);
        _mockStrategyTotalEquityInDebtAsset(state.totalEquity);
    }

    struct MintRedeemState {
        uint128 collateralInDebt;
        uint128 debt;
        uint128 targetRatio;
        uint128 userShares;
        uint128 totalShares;
    }

    function _mockState_MintRedeem(MintRedeemState memory state) internal {
        _mockState_CalculateStrategyCollateralRatioAndExcess(
            CalculateStrategyCollateralRatioAndExcessState({
                collateralInDebt: state.collateralInDebt,
                debt: state.debt,
                targetRatio: state.targetRatio
            })
        );
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateralInDebt);
        _mockStrategyTotalEquityInDebtAsset(state.collateralInDebt - state.debt);

        _mintShares(address(this), state.userShares);
        _mintShares(address(1), state.totalShares - state.userShares);

        // Mock convert rate in _calculateCollateralAndDebtToCoverEquity function. Not important for redeem test
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertDebtToCollateralAsset.selector),
            abi.encode(4 ether)
        );
    }

    struct CalculateStrategyCollateralRatioAndExcessState {
        uint128 collateralInDebt;
        uint128 debt;
        uint128 targetRatio;
    }

    function _mockState_CalculateStrategyCollateralRatioAndExcess(
        CalculateStrategyCollateralRatioAndExcessState memory state
    ) internal {
        _mockStrategyCollateralInDebtAsset(state.collateralInDebt);
        _mockStrategyDebt(state.debt);
        _mockStrategyTotalEquityInDebtAsset(
            state.collateralInDebt > state.debt ? state.collateralInDebt - state.debt : 0
        );
        _setStrategyCollateralRatios(
            CollateralRatios({
                minCollateralRatio: 0,
                targetCollateralRatio: state.targetRatio,
                maxCollateralRatio: type(uint256).max
            })
        );
    }

    function _mockConvertCollateral(uint256 collateral, uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertCollateralToDebtAsset.selector, collateral),
            abi.encode(debt)
        );
    }

    function _mockConvertDebt(uint256 debt, uint256 collateral) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertDebtToCollateralAsset.selector, debt),
            abi.encode(collateral)
        );
    }

    function _mockStrategyTotalEquityInDebtAsset(uint256 equity) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getEquityInDebtAsset.selector),
            abi.encode(equity)
        );
    }

    function _mockStrategyTotalEquityInCollateralAsset(uint256 equity) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getEquityInCollateralAsset.selector),
            abi.encode(equity)
        );
    }

    function _setStrategyRebalanceWhitelist(address caller, IRebalanceWhitelist whitelist) internal {
        vm.prank(caller);
        leverageManager.setStrategyRebalanceWhitelist(strategy, whitelist);
    }

    function _setStrategyActionFee(IStrategy _strategy, ExternalAction action, uint256 fee) internal {
        vm.prank(feeManagerRole);
        leverageManager.setStrategyActionFee(_strategy, action, fee);
    }

    function _setStrategyCollateralRatios(CollateralRatios memory ratios) internal {
        vm.prank(manager);
        leverageManager.setStrategyCollateralRatios(strategy, ratios);
    }

    function _mockStrategyDebt(uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getDebt.selector),
            abi.encode(debt)
        );
    }

    function _mockStrategyCollateralInDebtAsset(uint256 collateral) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getCollateralInDebtAsset.selector),
            abi.encode(collateral)
        );
    }
}
