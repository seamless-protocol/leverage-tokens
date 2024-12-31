// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerHarness} from "test/unit/LeverageManager/harness/LeverageManagerHarness.sol";
import {FeeManagerBaseTest} from "test/unit/FeeManager/FeeManagerBase.t.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {CollateralRatios} from "src/types/DataTypes.sol";

contract LeverageManagerBaseTest is FeeManagerBaseTest {
    address public lendingAdapter = makeAddr("lendingAdapter");
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");
    address public strategy = makeAddr("strategy");

    LeverageManagerHarness public leverageManager;

    function setUp() public virtual override {
        address leverageManagerImplementation = address(new LeverageManagerHarness());
        address leverageManagerProxy = UnsafeUpgrades.deployUUPSProxy(
            leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
        );

        leverageManager = LeverageManagerHarness(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
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

    function _getLendingAdapter() internal view returns (ILendingAdapter) {
        return leverageManager.getStrategyLendingAdapter(strategy);
    }

    function _createNewStrategy(address caller, Storage.StrategyConfig memory config) internal {
        vm.prank(caller);
        leverageManager.createNewStrategy(strategy, config);
    }

    function _setStrategyCollateralRatios(address caller, CollateralRatios memory ratios) internal {
        vm.prank(caller);
        leverageManager.setStrategyCollateralRatios(strategy, ratios);
    }

    function _setStrategyCollateralCap(address caller, uint256 cap) internal {
        vm.prank(caller);
        leverageManager.setStrategyCollateralCap(strategy, cap);
    }

    function _mintShares(address recipient, uint256 amount) internal {
        leverageManager.exposed_mintShares(strategy, recipient, amount);
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
        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({totalEquity: state.totalEquity, sharesTotalSupply: state.strategyTotalShares})
        );

        _mockStrategyCollateral(state.strategyCollateral);
        _mockConvertCollateral(state.depositAmount, state.depositAmountInDebtAsset);
        _mockStrategyTargetRatio(state.targetRatio);
    }

    function _mockStrategyCollateral(uint256 collateral) internal {
        vm.mockCall(
            address(_getLendingAdapter()),
            abi.encodeWithSelector(ILendingAdapter.getStrategyCollateral.selector, strategy),
            abi.encode(collateral)
        );
    }

    struct ConvertToSharesState {
        uint256 totalEquity;
        uint256 sharesTotalSupply;
    }

    function _mockState_ConvertToShareOrEquity(ConvertToSharesState memory state) internal {
        _mockStrategyTotalSupply(state.sharesTotalSupply);
        _mockStrategyTotalEquity(state.totalEquity);
    }

    struct CalculateExcessOfCollateralState {
        uint128 collateralInDebt;
        uint128 debt;
        uint256 targetRatio;
    }

    function _mockState_CalculateExcessOfCollateral(CalculateExcessOfCollateralState memory state) internal {
        _mockStrategyTargetRatio(state.targetRatio);
    }

    function _mockConvertCollateral(uint256 collateral, uint256 debt) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.convertCollateralToDebtAsset.selector, strategy, collateral),
            abi.encode(debt)
        );
    }

    function _mockStrategyTotalEquity(uint256 totalEquity) internal {
        vm.mockCall(
            address(leverageManager.getStrategyLendingAdapter(strategy)),
            abi.encodeWithSelector(ILendingAdapter.getStrategyEquityInDebtAsset.selector, strategy),
            abi.encode(totalEquity)
        );
    }

    function _mockStrategyTotalSupply(uint256 totalSupply) internal {
        leverageManager.exposed_mintShares(strategy, address(0), totalSupply);
    }

    function _mockStrategyTargetRatio(uint256 targetRatio) internal {
        vm.prank(manager);
        leverageManager.setStrategyCollateralRatios(
            strategy,
            CollateralRatios({
                minCollateralRatio: 0,
                targetCollateralRatio: targetRatio,
                maxCollateralRatio: type(uint256).max
            })
        );
    }
}
