// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IRebalanceRewardDistributor} from "src/interfaces/IRebalanceRewardDistributor.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {CollateralRatios, StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerBaseTest} from "../LeverageManager/LeverageManagerBase.t.sol";

contract DepositTest is LeverageManagerBaseTest {
    struct MockLeverageManagerStateForDeposit {
        uint256 collateral;
        uint256 debt;
        uint256 sharesTotalSupply;
    }

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

    function test_deposit() public {
        // collateral:debt is 2:1
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(0.5e8);

        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 200 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        _testDeposit(equityToAddInCollateralAsset, 0);
    }

    function testFuzz_deposit_SharesTotalSupplyGreaterThanZero(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset
    ) public {
        initialCollateral = uint128(bound(initialCollateral, 1, type(uint128).max));
        initialDebtInCollateralAsset =
            initialCollateral == 1 ? 0 : uint128(bound(initialDebtInCollateralAsset, 1, initialCollateral - 1));
        sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        equityToAddInCollateralAsset = uint128(bound(equityToAddInCollateralAsset, 1, type(uint96).max));

        uint256 allowedSlippage = _getAllowedCollateralRatioSlippage(initialDebtInCollateralAsset);
        _testDeposit(equityToAddInCollateralAsset, allowedSlippage);
    }

    function test_deposit_EquityToDepositIsZero() public {
        // CR is 3x
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 9, debt: 3, sharesTotalSupply: 3})
        );

        uint256 equityToAddInCollateralAsset = 0;
        (uint256 collateralToAdd, uint256 debtToBorrow,,) =
            leverageManager.exposed_previewAction(strategy, equityToAddInCollateralAsset, ExternalAction.Deposit);

        assertEq(collateralToAdd, 0);
        assertEq(debtToBorrow, 0);

        _testDeposit(equityToAddInCollateralAsset, 0);
    }

    function test_deposit_IsEmptyStrategy() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 0, debt: 0, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        uint256 collateralToAdd = 20 ether; // 2x CR

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        // Does not revert
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, equityToAddInCollateralAsset - 1);

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(afterState.collateralInDebtAsset, 20 ether); // 1:1 exchange rate, 2x CR
        assertEq(afterState.debt, 10 ether);
        assertEq(afterState.collateralRatio, 2 * _BASE_RATIO());
    }

    function test_deposit_ZeroSharesTotalSupplyWithDust() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 3, debt: 1, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 1 ether;
        uint256 expectedCollateralToAdd = 2 ether; // 2x target CR
        uint256 expectedDebtToBorrow = 1 ether;
        uint256 expectedShares = Math.mulDiv(
            equityToAddInCollateralAsset,
            10 ** _DECIMALS_OFFSET(),
            beforeState.collateral - beforeState.debt + 1, // 1:1 collateral to debt exchange rate in this test
            Math.Rounding.Floor
        );

        deal(address(collateralToken), address(this), expectedCollateralToAdd);
        collateralToken.approve(address(leverageManager), expectedCollateralToAdd);

        (uint256 collateralAdded, uint256 debtBorrowed, uint256 sharesReceived, uint256 shareFeeCharged) =
            leverageManager.deposit(strategy, equityToAddInCollateralAsset, expectedShares);

        assertEq(collateralAdded, expectedCollateralToAdd);
        assertEq(debtBorrowed, expectedDebtToBorrow);
        assertEq(sharesReceived, expectedShares);
        assertEq(shareFeeCharged, 0);

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(afterState.collateralInDebtAsset, expectedCollateralToAdd + beforeState.collateral);
        assertEq(afterState.debt, expectedDebtToBorrow + beforeState.debt); // 1:1 collateral to debt exchange rate, 2x target CR
        assertEq(
            afterState.collateralRatio,
            Math.mulDiv(
                expectedCollateralToAdd + beforeState.collateral,
                _BASE_RATIO(),
                expectedDebtToBorrow + beforeState.debt,
                Math.Rounding.Floor
            )
        );
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_SlippageIsTooHigh(uint128 sharesSlippage) public {
        vm.assume(sharesSlippage > 0);

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 10 ether})
        );

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd,, uint256 shares,) =
            leverageManager.exposed_previewAction(strategy, equityToAddInCollateralAsset, ExternalAction.Deposit);
        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        uint256 minShares = shares + sharesSlippage; // More than previewed

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, shares, minShares));
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, minShares);
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

    function _prepareLeverageManagerStateForDeposit(MockLeverageManagerStateForDeposit memory state) internal {
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

    function _testDeposit(uint256 equityToAddInCollateralAsset, uint256 collateralRatioDeltaRelative) internal {
        StrategyState memory beforeState = leverageManager.exposed_getStrategyState(strategy);
        uint256 beforeSharesTotalSupply = strategy.totalSupply();

        // The assertion for collateral ratio before and after the deposit in this helper only makes sense to use
        // if the strategy has totalSupply > 0 before deposit, as a deposit of equity into a strategy with totalSupply = 0
        // will not respect the current collateral ratio of the strategy, it just uses the target collateral ratio
        require(
            beforeSharesTotalSupply != 0, "Shares total supply must be non-zero to use _testDeposit helper function"
        );

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityToAddInCollateralAsset, ExternalAction.Deposit);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(
            strategy, address(this), collateralToAdd, debtToBorrow, equityToAddInCollateralAsset, shares, sharesFee
        );
        (uint256 collateralAdded, uint256 debtBorrowed, uint256 sharesReceived, uint256 shareFeeCharged) =
            leverageManager.deposit(strategy, equityToAddInCollateralAsset, shares);

        assertEq(sharesReceived, shares);
        assertEq(strategy.balanceOf(address(this)), sharesReceived, "Shares received mismatch");
        assertEq(shareFeeCharged, sharesFee, "Share fee charged mismatch");

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(
            afterState.collateralInDebtAsset,
            beforeState.collateralInDebtAsset + lendingAdapter.convertCollateralToDebtAsset(collateralToAdd),
            "Collateral in strategy after deposit mismatch"
        );
        assertEq(collateralAdded, collateralToAdd, "Collateral added mismatch");
        assertEq(afterState.debt, beforeState.debt + debtToBorrow, "Debt in strategy after deposit mismatch");
        assertEq(debtBorrowed, debtToBorrow, "Debt borrowed mismatch");
        assertEq(debtToken.balanceOf(address(this)), debtToBorrow, "Debt tokens received mismatch");

        assertApproxEqRel(
            afterState.collateralRatio,
            beforeState.collateralRatio,
            collateralRatioDeltaRelative,
            "Collateral ratio after deposit mismatch"
        );
        assertGe(
            afterState.collateralRatio,
            beforeState.collateralRatio,
            "Collateral ratio after deposit should be greater than or equal to before"
        );
    }
}
