// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
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
                collateralCap: type(uint256).max
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

    function testFuzz_deposit_StrategyWithinMinMaxCollateralRatio(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset
    ) public {
        // If the initial collateral is 1, the amount of debt in the strategy will be calculated as either 0 or 1 if we
        // calculate the initial debt to respect the min and max collateral ratios, as we do in this test. That would
        // result in an initial collateral ratio of either type(uint256).max or 1e8, which both would revert the deposit.
        //     - 1 collateral and 1 debtInCollateralAsset would result in a CR of 1e8. This causes a revert in previewDeposit
        //       due to division by zero for the calculation of collateralToAdd. This also implies a 100% CR - in practice,
        //       the strategy should be rebalanced before this point (or liquidated)
        //     - 1 collateral and 0 debtInCollateralAsset would result in a CR of type(uint256).max. This causes a revert
        //       in deposit because the strategy is not within the collateral ratio range and it holds > 0 collateral or debt.
        //       The strategy must be rebalanced (or price action must occur) before a deposit can occur
        vm.assume(initialCollateral != 1);

        equityToAddInCollateralAsset = uint128(bound(equityToAddInCollateralAsset, 1, type(uint128).max));

        // collateral:debt is 1:2
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        uint256 minCollateralRatio = _BASE_RATIO() + 1;
        uint256 maxCollateralRatio = 3 * _BASE_RATIO();

        uint256 maxInitialDebtInCollateralAsset =
            Math.mulDiv(initialCollateral, _BASE_RATIO(), minCollateralRatio, Math.Rounding.Floor);
        uint256 minInitialDebtInCollateralAsset =
            Math.mulDiv(initialCollateral, _BASE_RATIO(), maxCollateralRatio, Math.Rounding.Ceil);
        initialDebtInCollateralAsset = uint128(
            bound(initialDebtInCollateralAsset, minInitialDebtInCollateralAsset, maxInitialDebtInCollateralAsset)
        );

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: initialCollateral,
                debt: lendingAdapter.convertCollateralToDebtAsset(initialDebtInCollateralAsset),
                sharesTotalSupply: sharesTotalSupply
            })
        );

        uint256 allowedSlippage = _getAllowedCollateralRatioSlippage(initialCollateral);
        _testDeposit(equityToAddInCollateralAsset, allowedSlippage);
    }

    function test_deposit_RevertIf_CurrentCollateralRatioTooHigh() public {
        // CR is 10x
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 1000 ether, debt: 100 ether, sharesTotalSupply: 100 ether})
        );

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        // CR is 10x, but the max is 3x
        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.CollateralRatioOutsideRange.selector, 10e8));
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, 0);
    }

    function test_deposit_RevertIf_CurrentCollateralRatioTooLow() public {
        _setStrategyCollateralRatios(
            CollateralRatios({minCollateralRatio: 2e8, targetCollateralRatio: 3e8, maxCollateralRatio: 4e8})
        );

        // CR is 1.5e8, but the min is 2e8
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 150 ether, debt: 100 ether, sharesTotalSupply: 100 ether})
        );

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.CollateralRatioOutsideRange.selector, 1.5e8));
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, 0);
    }

    function test_deposit_EquityToDepositIsZero() public {
        // CR is 3x
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 9, debt: 3, sharesTotalSupply: 3})
        );

        uint256 equityToAddInCollateralAsset = 0;
        (uint256 collateralToAdd, uint256 debtToBorrow,,) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        assertEq(collateralToAdd, 0);
        assertEq(debtToBorrow, 0);

        _testDeposit(equityToAddInCollateralAsset, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_SlippageIsTooHigh(uint128 sharesSlippage) public {
        vm.assume(sharesSlippage > 0);

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 10 ether})
        );

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd,, uint256 shares,) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        uint256 minShares = shares + sharesSlippage; // More than previewed

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, shares, minShares));
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, minShares);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_CollateralCapExceeded(uint128 excessCollateral) public {
        vm.assume(excessCollateral > 0);

        uint256 collateralBefore = 100 ether;
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: collateralBefore,
                debt: 50 ether,
                sharesTotalSupply: 100 ether
            })
        );

        _setStrategyCollateralCap(manager, 110 ether);

        // Strategy is at 2x ratio, so adding 5 ether will require 10 ether of collateral which will bring the strategy to the cap.
        uint256 equityToAddInCollateralAsset = uint256(5 ether) + excessCollateral;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageManager.CollateralCapExceeded.selector, collateralBefore + collateralToAdd, 110 ether
            )
        );
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, 0);
    }

    function test_deposit_IsEmptyStrategy() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 0, debt: 0, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares,) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        // Does not revert
        leverageManager.deposit(strategy, equityToAddInCollateralAsset, shares);

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(afterState.collateral, collateralToAdd, "Collateral mismatch");
        assertEq(afterState.debt, debtToBorrow, "Debt mismatch");
        assertEq(afterState.collateralRatio, 2 * _BASE_RATIO(), "Collateral ratio mismatch");
    }

    /// @dev The allowed slippage in collateral ratio of the strategy after a deposit should scale with the size of the
    /// initial collateral in the strategy, as smaller strategies may incur a higher collateral ratio delta after the
    /// deposit due to rounding.
    ///
    /// For example, if the initial collateral is 3 and the initial debt is 1 (with collateral and debt normalized) then the
    /// collateral ratio is 300000000. If a deposit of 1 equity is made, then the required collateral is 2 and the required
    /// debt is 1. So the resulting collateral is 5 and the debt is 4. The resulting collateral ratio is 250000000, which is
    /// a ~16.67% change from the initial collateral ratio.
    ///
    /// As the intial collateral scales up in size, the allowed slippage should scale down as more precision can be achieved
    /// for the collateral ratio:
    ///    initialCollateral < 100: 1e18 (100% slippage)
    ///    initialCollateral < 1000: 0.1e18 (10% slippage)
    ///    initialCollateral < 10000: 0.01e18 (1% slippage)
    ///    initialCollateral < 100000: 0.001e18 (0.1% slippage)
    ///    initialCollateral < 1000000: 0.0001e18 (0.01% slippage)
    ///    initialCollateral < 10000000: 0.00001e18 (0.001% slippage)
    ///    initialCollateral < 100000000: 0.000001e18 (0.0001% slippage)
    ///    initialCollateral < 1000000000: 0.0000001e18 (0.00001% slippage)
    ///    initialCollateral >= 1000000000: 0.00000001e18 (0.000001% slippage)
    ///
    /// Note: We can at maximum support up to 0.00000001e18 (0.000001% slippage) due to the base collateral ratio
    ///       being 1e8
    function _getAllowedCollateralRatioSlippage(uint256 initialCollateral)
        internal
        pure
        returns (uint256 allowedSlippagePercentage)
    {
        if (initialCollateral == 0) {
            return 0;
        }

        uint256 i = Math.log10(initialCollateral);

        // This is the maximum slippage that we can support due to the precision of the collateral ratio being
        // 1e8 (1e18 / 1e8 = 1e10 = 0.00000001e18)
        if (i > 8) return 0.00000001e18;

        // If i <= 1, that means initialCollateral < 100, thus slippage = 1e18
        // Otherwise slippage = 1e18 / (10^(i - 1))
        return (i <= 1) ? 1e18 : (1e18 / (10 ** (i - 1)));
    }

    function _prepareLeverageManagerStateForDeposit(MockLeverageManagerStateForDeposit memory state) internal {
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateral);

        _mockState_ConvertToShares(
            ConvertToSharesState({
                totalEquity: state.collateral - lendingAdapter.convertDebtToCollateralAsset(state.debt),
                sharesTotalSupply: state.sharesTotalSupply
            })
        );
    }

    function _testDeposit(uint256 equityToAddInCollateralAsset, uint256 collateralRatioDeltaRelative) internal {
        StrategyState memory beforeState = leverageManager.exposed_getStrategyState(strategy);

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(
            strategy, address(this), collateralToAdd, debtToBorrow, equityToAddInCollateralAsset, shares, sharesFee
        );
        uint256 sharesReceived = leverageManager.deposit(strategy, equityToAddInCollateralAsset, shares);

        assertEq(sharesReceived, shares);
        assertEq(strategy.balanceOf(address(this)), sharesReceived, "Shares received mismatch");

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(
            afterState.collateral,
            beforeState.collateral + collateralToAdd,
            "Collateral in strategy after deposit mismatch"
        );
        assertEq(afterState.debt, beforeState.debt + debtToBorrow, "Debt in strategy after deposit mismatch");
        assertEq(debtToken.balanceOf(address(this)), debtToBorrow, "Debt tokens received mismatch");

        if (beforeState.collateralRatio != type(uint256).max) {
            assertApproxEqRel(
                afterState.collateralRatio,
                beforeState.collateralRatio,
                collateralRatioDeltaRelative,
                "Collateral ratio after deposit mismatch"
            );
        } else {
            assertEq(
                afterState.collateralRatio,
                2 * _BASE_RATIO(),
                "Collateral ratio mismatch after deposit into strategy with max CR"
            );
        }
    }
}
