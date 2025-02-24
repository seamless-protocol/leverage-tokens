// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerBaseTest} from "../LeverageManager/LeverageManagerBase.t.sol";

contract PreviewActionTest is LeverageManagerBaseTest {
    function setUp() public override {
        super.setUp();
        _createNewStrategy(
            manager,
            Storage.StrategyConfig({
                lendingAdapter: ILendingAdapter(address(lendingAdapter)),
                minCollateralRatio: _BASE_RATIO() + 1,
                maxCollateralRatio: 3 * _BASE_RATIO(),
                targetCollateralRatio: 2 * _BASE_RATIO(), // 2x leverage
                collateralCap: type(uint256).max,
                rebalanceRewardDistributor: IRebalanceRewardDistributor(address(0)),
                rebalanceWhitelist: IRebalanceWhitelist(address(0))
            }),
            address(collateralToken),
            address(debtToken),
            "dummy name",
            "dummy symbol"
        );
    }

    function test_previewAction_WithFee() public {
        _setStrategyActionFee(strategy, ExternalAction.Deposit, 0.05e4); // 5% fee
        _setStrategyActionFee(strategy, ExternalAction.Withdraw, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equity = 10 ether;
        (uint256 collateral, uint256 debt, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        assertEq(collateral, 20 ether - 1);
        assertEq(debt, 20 ether - 1);
        assertEq(expectedShares, 19 ether - 1); // 5% fee
        assertEq(sharesFee, 1 ether);

        (collateral, debt, expectedShares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 20 ether - 1);
        assertEq(debt, 20 ether - 1);
        assertEq(expectedShares, 21 ether - 1); // 5% fee
        assertEq(sharesFee, 1 ether);
    }

    function test_previewDeposit_WithoutFee() public {
        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityToAdd, ExternalAction.Deposit);

        assertEq(collateralToAdd, 20 ether - 1);
        assertEq(debtToBorrow, 10 ether - 1);
        assertEq(expectedShares, 20 ether - 1);
        assertEq(sharesFee, 0);

        (collateralToAdd, debtToBorrow, expectedShares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityToAdd, ExternalAction.Withdraw);

        assertEq(collateralToAdd, 20 ether - 1);
        assertEq(debtToBorrow, 10 ether); // Rounded up
        assertEq(expectedShares, 20 ether - 1);
        assertEq(sharesFee, 0);
    }

    function test_previewAction_ZeroEquity() public view {
        uint256 equity = 0;
        (uint256 collateral, uint256 debt, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(expectedShares, 0);
        assertEq(sharesFee, 0);

        (collateral, debt, expectedShares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(expectedShares, 0);
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewAction_ZeroSharesTotalSupply(uint128 initialCollateral, uint128 initialDebt) public {
        initialDebt = initialCollateral == 0 ? 0 : uint128(bound(initialDebt, 0, initialCollateral - 1));

        MockLeverageManagerStateForAction memory beforeState =
            MockLeverageManagerStateForAction({collateral: initialCollateral, debt: initialDebt, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForAction(beforeState);

        uint256 equity = 1 ether;

        (uint256 collateral, uint256 debt, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        // Follows 2x target ratio
        assertEq(collateral, 2 ether);
        assertEq(debt, 1 ether);

        uint256 expectedShares = leverageManager.exposed_convertToShares(strategy, equity);
        assertEq(shares, expectedShares);
        assertEq(sharesFee, 0);

        (collateral, debt, shares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 2 ether);
        assertEq(debt, 1 ether);
        assertEq(shares, expectedShares);
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityInCollateralAsset,
        uint16 fee,
        uint8 actionNum
    ) public {
        ExternalAction action = ExternalAction(actionNum % 2);
        fee = uint16(bound(fee, 0, 1e4)); // 0% to 100% fee
        _setStrategyActionFee(strategy, action, fee);

        initialDebtInCollateralAsset = uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral));

        if (initialCollateral == 0 && initialDebtInCollateralAsset == 0) {
            sharesTotalSupply = 0;
        } else {
            sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));
        }

        _prepareLeverageManagerStateForAction(
            MockLeverageManagerStateForAction({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        if (action == ExternalAction.Deposit) {
            equityInCollateralAsset = uint128(bound(equityInCollateralAsset, 1, type(uint96).max));
        } else {
            equityInCollateralAsset =
                uint128(bound(equityInCollateralAsset, 0, initialCollateral - initialDebtInCollateralAsset));
        }

        // Get state prior to action
        StrategyState memory prevState = leverageManager.exposed_getStrategyState(strategy);

        (uint256 collateral, uint256 debt, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityInCollateralAsset, action);

        // Calculate state after action
        (, uint256 newDebt, uint256 newCollateralRatio) =
            _getNewStrategyState(initialCollateral, initialDebtInCollateralAsset, collateral, debt, action);

        {
            // First validate if shares and fee are properly calculated
            uint256 sharesBeforeFeeExpected = leverageManager.exposed_convertToShares(strategy, equityInCollateralAsset);
            (uint256 sharesAfterFeeExpected, uint256 sharesFeeExpected) =
                leverageManager.exposed_computeFeeAdjustedShares(strategy, sharesBeforeFeeExpected, action);

            assertEq(sharesFee, sharesFeeExpected);
            assertEq(shares, sharesAfterFeeExpected);
        }

        // If full withdraw is done then the collateral ratio should be max
        if (_isFullWithdraw(initialDebtInCollateralAsset, debt, action)) {
            assertEq(newCollateralRatio, type(uint256).max);
            return;
        }

        // If strategy was initially empty then action should be done by respecting the target ratio
        if (_isStrategyEmpty(initialCollateral)) {
            assertEq(newCollateralRatio, 2 * _BASE_RATIO());
            return;
        }

        // Otherwise, the action should be done by respecting the current collateral ratio
        // There is some tolerance on collateral ratio due to rounding depending on debt size
        // It is important to calculate tolerance with smaller debt (for deposit before action for withdraw after action)

        uint256 respectiveDebt = action == ExternalAction.Deposit ? initialDebtInCollateralAsset : newDebt;
        uint256 from = action == ExternalAction.Deposit ? newCollateralRatio : prevState.collateralRatio;
        uint256 to = action == ExternalAction.Deposit ? prevState.collateralRatio : newCollateralRatio;
        assertApproxEqRel(
            from,
            to,
            _getAllowedCollateralRatioSlippage(respectiveDebt),
            "Collateral ratio after deposit should be within the allowed slippage"
        );
        assertGe(
            newCollateralRatio,
            prevState.collateralRatio,
            "Collateral ratio after deposit should be greater than or equal to before"
        );
    }

    function _getNewStrategyState(
        uint256 initialCollateral,
        uint256 initialDebtInCollateralAsset,
        uint256 collateralChange,
        uint256 debtChange,
        ExternalAction action
    ) internal view returns (uint256 newCollateral, uint256 newDebt, uint256 newCollateralRatio) {
        debtChange = lendingAdapter.convertDebtToCollateralAsset(debtChange);

        newCollateral = action == ExternalAction.Deposit
            ? initialCollateral + collateralChange
            : initialCollateral - collateralChange;

        newDebt = action == ExternalAction.Deposit
            ? initialDebtInCollateralAsset + debtChange
            : initialDebtInCollateralAsset - debtChange;

        newCollateralRatio = newDebt != 0 ? (newCollateral * _BASE_RATIO()) / newDebt : type(uint256).max;

        return (newCollateral, newDebt, newCollateralRatio);
    }

    function _isFullWithdraw(uint256 initialDebt, uint256 debtChange, ExternalAction action)
        internal
        view
        returns (bool)
    {
        return
            action == ExternalAction.Withdraw && initialDebt == lendingAdapter.convertDebtToCollateralAsset(debtChange);
    }

    function _isStrategyEmpty(uint256 collateral) private pure returns (bool) {
        return collateral == 0;
    }

    struct MockLeverageManagerStateForAction {
        uint256 collateral;
        uint256 debt;
        uint256 sharesTotalSupply;
    }

    function _prepareLeverageManagerStateForAction(MockLeverageManagerStateForAction memory state) internal {
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateral);

        uint256 debtInCollateralAsset = lendingAdapter.convertDebtToCollateralAsset(state.debt);
        _mockState_ConvertToShares(
            ConvertToSharesState({
                totalEquity: state.collateral > debtInCollateralAsset ? state.collateral - debtInCollateralAsset : 0,
                sharesTotalSupply: state.sharesTotalSupply
            })
        );
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
            return 0;
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
