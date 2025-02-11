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

        // Mint some shares to test with
        vm.prank(address(leverageManager));
        strategy.mint(address(1), 100 ether);
    }

    function test_deposit_StrategyOnTargetCollateralRatio() public {
        _mockLendingAdapterExchangeRate(1e8); // 1:1

        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        _testDeposit(equityToAdd, 0);
    }

    function testFuzz_deposit_StrategyWithinMinMaxCollateralRatio(
        uint256 debt,
        uint128 sharesTotalSupply,
        uint128 initialEquity,
        uint128 equityToAdd
    ) public {
        // Ensures that the strategy has a collateral ratio < type(uint256).max by being greater than zero
        vm.assume(initialEquity > 0);
        // Ensures that the calculation in previewDeposit for determining the debt to borrow is not zero:
        //     debtToBorrow = equityToAdd * BASE_RATIO / (currentCollateralRatio - BASE_RATIO)
        // Using > 1 because the maximum collateral ratio in this test is 3x, so values <= 1 will result in
        // debtToBorrow = 0. If debtToBorrow = 0, then the collateral ratio will change more significantly
        // after deposit than expected with smaller values of collateral and debt in the strategy.
        vm.assume(equityToAdd > 1);

        _mockLendingAdapterExchangeRate(1e8); // 1:1 exchange rate for simplicity

        // Debt should be an amount that results in a CR between min and max collateral ratio
        // For maxDebtBeforeRebalance, we round down because the collateral ratio is calculated as collateral / debt,
        // and we want to ensure that the collateral ratio is less than the max collateral ratio
        uint256 maxDebtBeforeRebalance =
            Math.mulDiv(initialEquity, _BASE_RATIO(), _BASE_RATIO() + 1 - _BASE_RATIO(), Math.Rounding.Floor);
        // For minDebtBeforeRebalance, we round up because the collateral ratio is calculated as collateral / debt,
        // and we want to ensure that the collateral ratio is greater than the min collateral ratio
        uint256 minDebtBeforeRebalance =
            Math.mulDiv(initialEquity, _BASE_RATIO(), 3 * _BASE_RATIO() - _BASE_RATIO(), Math.Rounding.Ceil);
        debt = bound(debt, minDebtBeforeRebalance, maxDebtBeforeRebalance);

        // Collateral should be the sum of the equity in collateral asset and the debt asset (1:1 exchange rate)
        uint256 collateral = initialEquity + debt;

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: collateral,
                debt: debt,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        _testDeposit(equityToAdd, 0.001e18);
    }

    function test_deposit_RevertIf_CurrentCollateralRatioTooHigh() public {
        _mockLendingAdapterExchangeRate(1e8); // 1:1

        // CR is 10x
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 1000 ether, debt: 100 ether, sharesTotalSupply: 100 ether})
        );

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAdd);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        // CR is 10x, but the max is 3x
        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.CollateralRatioOutsideRange.selector, 10e8));
        leverageManager.deposit(strategy, equityToAdd, 0);
    }

    function test_deposit_RevertIf_CurrentCollateralRatioTooLow() public {
        _mockLendingAdapterExchangeRate(1e8); // 1:1

        _setStrategyCollateralRatios(
            CollateralRatios({minCollateralRatio: 2e8, targetCollateralRatio: 3e8, maxCollateralRatio: 4e8})
        );

        // CR is 1.5e8, but the min is 2e8
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 150 ether, debt: 100 ether, sharesTotalSupply: 100 ether})
        );

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAdd);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.CollateralRatioOutsideRange.selector, 1.5e8));
        leverageManager.deposit(strategy, equityToAdd, 0);
    }

    function test_deposit_RevertIf_DebtToBorrowIsZero() public {
        _mockLendingAdapterExchangeRate(1e8); // 1:1

        // CR is 3x
        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 9, debt: 3, sharesTotalSupply: 3})
        );

        // When adding 1 wei of equity to a strategy with very little collateral and debt, debtToBorrow will be zero
        // because the formula for debtToBorrow is:
        //     debtToBorrow = equityToAdd * BASE_RATIO / (currentCollateralRatio - BASE_RATIO)
        //     debtToBorrow = 1 * 1e8 / (3e8 - 1e8) = 0 (rounded down)
        // In these cases we should revert, as the collateral ratio will change significantly in this scenario:
        //     newCollateralRatio = (collateral + collateralToAdd) / (debt + debtToBorrow)
        //     newCollateralRatio = (9 + 1) / (3 + 0) ~= 3.3333e8 (approx 10 percentage change)
        uint256 equityToAdd = 1;
        (uint256 collateralToAdd, uint256 debtToBorrow,,) = leverageManager.previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 1);
        assertEq(debtToBorrow, 0);

        vm.expectRevert(ILeverageManager.InvalidBorrowForDeposit.selector);
        leverageManager.deposit(strategy, equityToAdd, 0);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_SlippageIsTooHigh(uint128 sharesSlippage) public {
        vm.assume(sharesSlippage > 0);

        _mockLendingAdapterExchangeRate(1e8); // 1:1

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 10 ether})
        );

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd,, uint256 shares,) = leverageManager.previewDeposit(strategy, equityToAdd);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        uint256 minShares = shares + sharesSlippage; // More than previewed

        vm.expectRevert(abi.encodeWithSelector(ILeverageManager.SlippageTooHigh.selector, shares, minShares));
        leverageManager.deposit(strategy, equityToAdd, minShares);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_deposit_RevertIf_CollateralCapExceeded(uint128 excessCollateral) public {
        vm.assume(excessCollateral > 0);

        _mockLendingAdapterExchangeRate(1e8); // 1:1

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
        uint256 equityToAdd = 5 ether + excessCollateral;
        (uint256 collateralToAdd,,,) = leverageManager.previewDeposit(strategy, equityToAdd);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILeverageManager.CollateralCapExceeded.selector, collateralBefore + collateralToAdd, 110 ether
            )
        );
        leverageManager.deposit(strategy, equityToAdd, 0);
    }

    function _prepareLeverageManagerStateForDeposit(MockLeverageManagerStateForDeposit memory state) internal {
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateral);

        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({
                totalEquity: lendingAdapter.convertCollateralToDebtAsset(state.collateral) - state.debt,
                sharesTotalSupply: state.sharesTotalSupply
            })
        );
    }

    function _testDeposit(uint256 equityToAdd, uint256 collateralRatioDeltaRelative) internal {
        StrategyState memory beforeState = leverageManager.exposed_getStrategyState(strategy);

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAdd);

        deal(address(collateralToken), address(this), collateralToAdd);
        collateralToken.approve(address(leverageManager), collateralToAdd);

        vm.expectEmit(true, true, true, true);
        emit ILeverageManager.Deposit(
            strategy, address(this), collateralToAdd, debtToBorrow, equityToAdd, shares, sharesFee
        );
        uint256 sharesReceived = leverageManager.deposit(strategy, equityToAdd, shares);

        assertEq(sharesReceived, shares);

        StrategyState memory afterState = leverageManager.exposed_getStrategyState(strategy);
        assertEq(afterState.collateral, beforeState.collateral + collateralToAdd);
        assertEq(afterState.debt, beforeState.debt + debtToBorrow);
        assertApproxEqRel(afterState.collateralRatio, beforeState.collateralRatio, collateralRatioDeltaRelative);
    }
}
