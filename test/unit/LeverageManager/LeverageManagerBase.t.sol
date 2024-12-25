// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependencies imports
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/wrappers/FeeManagerHarness.sol";

contract LeverageManagerBaseTest is FeeManagerBaseTest {
    address public lendingAdapter = makeAddr("lendingAdapter");
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");

    LeverageManagerHarness public leverageManager;

    function setUp() public virtual override {
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = address(
            new ERC1967Proxy(
                leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
            )
        );

        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        leverageManager.grantRole(leverageManager.FEE_MANAGER_ROLE(), feeManagerRole);
        feeManager = FeeManagerHarness(address(leverageManager));
        vm.stopPrank();
    }

    function test_setUp() public view virtual override {
        assertTrue(leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }

    function _BASE_RATIO() internal view returns (uint256) {
        return leverageManager.BASE_RATIO();
    }

    function _getLendingAdapter(address strategy) internal view returns (ILendingAdapter) {
        return leverageManager.getStrategyLendingAdapter(strategy);
    }

    function _setStrategyCore(address caller, address strategy, Storage.StrategyCore memory core) internal {
        vm.prank(caller);
        leverageManager.setStrategyCore(strategy, core);
    }

    function _setStrategyCollateralRatios(address caller, address strategy, Storage.CollateralRatios memory ratios)
        internal
    {
        vm.prank(caller);
        leverageManager.setStrategyCollateralRatios(strategy, ratios);
    }

    function _setStrategyCollateralCap(address caller, address strategy, uint256 cap) internal {
        vm.prank(caller);
        leverageManager.setStrategyCollateralCap(strategy, cap);
    }

    function _mintShares(address strategy, address recipient, uint256 amount) internal {
        leverageManager.mintShares(strategy, recipient, amount);
    }

    struct CalculateDebtAndSharesState {
        address strategy;
        uint256 targetRatio;
        uint128 collateral;
        uint128 convertedCollateral;
        uint128 totalEquity;
        uint128 strategyTotalShares;
    }

    function _mockState_CalculateDebtAndShares(CalculateDebtAndSharesState memory state) internal {
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({
                strategy: state.strategy,
                totalEquity: state.totalEquity,
                sharesTotalSupply: state.strategyTotalShares
            })
        );

        _mockConvertCollateral(state.strategy, state.collateral, state.convertedCollateral);
        _mockStrategyTargetRatio(state.strategy, state.targetRatio);
    }

    struct ConvertToSharesState {
        address strategy;
        uint256 totalEquity;
        uint256 sharesTotalSupply;
    }

    function _mockState_ConvertToShareOrEquity(ConvertToSharesState memory state) internal {
        _mockStrategyTotalSupply(state.strategy, state.sharesTotalSupply);
        _mockStrategyTotalEquity(state.strategy, state.totalEquity);
    }

    struct CalculateExcessOfCollateralState {
        address strategy;
        uint128 collateralInDebt;
        uint128 debt;
        uint256 targetRatio;
    }

    function _mockState_CalculateExcessOfCollateral(CalculateExcessOfCollateralState memory state) internal {
        _mockStrategyCollateralInDebtAsset(state.strategy, state.collateralInDebt);
        _mockStrategyDebt(state.strategy, state.debt);
        _mockStrategyTargetRatio(state.strategy, state.targetRatio);
    }

    function _mockConvertCollateral(address strategy, uint256 collateral, uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertCollateralToDebtAsset.selector, strategy, collateral),
            abi.encode(debt)
        );
    }

    function _mockStrategyCollateralInDebtAsset(address strategy, uint256 collateral) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getStrategyCollateralInDebtAsset.selector, strategy),
            abi.encode(collateral)
        );
    }

    function _mockConvertDebtToCollateralAsset(address strategy, uint256 debt, uint256 collateral) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertBaseToCollateralAsset.selector, strategy, debt),
            abi.encode(collateral)
        );
    }

    function _mockStrategyDebt(address strategy, uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getStrategyDebt.selector, strategy),
            abi.encode(debt)
        );
    }

    function _mockStrategyTotalEquity(address strategy, uint256 totalEquity) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getStrategyEquityInDebtAsset.selector, strategy),
            abi.encode(totalEquity)
        );
    }

    function _mockStrategyTotalSupply(address strategy, uint256 totalSupply) internal {
        leverageManager.mintShares(strategy, address(0), totalSupply);
    }

    function _mockStrategyTargetRatio(address strategy, uint256 targetRatio) internal {
        vm.prank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({minForRebalance: 0, target: targetRatio, maxForRebalance: type(uint256).max})
        );
    }
}
