// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract PreviewDepositTest is LeverageManagerBaseTest {
    struct MockLeverageManagerStateForPreviewDeposit {
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

    function test_previewDeposit_WithFee() public {
        _setStrategyActionFee(strategy, IFeeManager.Action.Deposit, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForPreviewDeposit memory beforeState = MockLeverageManagerStateForPreviewDeposit({
            collateral: 100 ether,
            debt: 100 ether,
            sharesTotalSupply: 100 ether
        });

        _prepareLeverageManagerStateForPreviewDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 20 ether);
        assertEq(debtToBorrow, 20 ether);
        assertEq(expectedShares, 19 ether);
        assertEq(sharesFee, 1 ether);
    }

    function test_previewDeposit_WithoutFee() public {
        MockLeverageManagerStateForPreviewDeposit memory beforeState = MockLeverageManagerStateForPreviewDeposit({
            collateral: 100 ether,
            debt: 50 ether,
            sharesTotalSupply: 100 ether
        });

        _prepareLeverageManagerStateForPreviewDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 20 ether);
        assertEq(debtToBorrow, 10 ether);
        assertEq(expectedShares, 20 ether - 1); // 20 ether - 1 because of equity offset in convertToShares
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewDeposit(
        uint256 debt,
        uint128 sharesTotalSupply,
        uint128 initialEquity,
        uint128 equityToAdd,
        uint16 fee
    ) public {
        // Ensures that the strategy has a collateral ratio < type(uint256).max by being greater than zero
        vm.assume(initialEquity > 0);

        fee = uint16(bound(fee, 0, 1e4)); // 0% to 100% fee
        _setStrategyActionFee(strategy, IFeeManager.Action.Deposit, fee);

        // Debt should be an amount that results in a CR between min and max collateral ratio
        uint256 minDebtBeforeRebalance = initialEquity * _BASE_RATIO() / (3 * _BASE_RATIO() - _BASE_RATIO());
        uint256 maxDebtBeforeRebalance = initialEquity * _BASE_RATIO() / (_BASE_RATIO() + 1 - _BASE_RATIO());
        debt = bound(debt, minDebtBeforeRebalance, maxDebtBeforeRebalance);

        // Collateral should be the sum of the equity in collateral asset and the debt asset (1:1 exchange rate)
        uint256 collateral = initialEquity + debt;

        _prepareLeverageManagerStateForPreviewDeposit(
            MockLeverageManagerStateForPreviewDeposit({
                collateral: collateral,
                debt: debt,
                sharesTotalSupply: sharesTotalSupply
            })
        );

        StrategyState memory state = leverageManager.exposed_getStrategyState(strategy);

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAdd);

        // Check that the debt to borrow and collateral to add match the current collateral ratio of the strategy
        assertEq(debtToBorrow, equityToAdd * _BASE_RATIO() / (state.collateralRatio - _BASE_RATIO()));
        assertEq(collateralToAdd, equityToAdd + debtToBorrow);

        uint256 sharesBeforeFee =
            equityToAdd * (sharesTotalSupply + 10 ** leverageManager.DECIMALS_OFFSET()) / (state.equity + 1);
        uint256 sharesFeeExpected = Math.mulDiv(sharesBeforeFee, fee, 1e4, Math.Rounding.Ceil);

        // Check that the shares to be minted are wrt the new equity being added to the strategy and the fee applied
        assertEq(sharesFee, sharesFeeExpected);
        assertEq(shares, sharesBeforeFee - sharesFee);
    }

    function test_previewDeposit_CurrentCollateralRatioIsMax() public {
        MockLeverageManagerStateForPreviewDeposit memory beforeState =
            MockLeverageManagerStateForPreviewDeposit({collateral: 100 ether, debt: 0, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForPreviewDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        // Current collateral ratio is max, so the target ratio is used (2x)
        assertEq(debtToBorrow, 10 ether);
        assertEq(collateralToAdd, 20 ether);
        assertEq(shares, 10 ether);
        assertEq(sharesFee, 0);
    }

    function _prepareLeverageManagerStateForPreviewDeposit(MockLeverageManagerStateForPreviewDeposit memory state)
        internal
    {
        lendingAdapter.mockDebt(state.debt);
        lendingAdapter.mockCollateral(state.collateral);

        _mockState_ConvertToShareOrEquity(
            ConvertToSharesState({
                totalEquity: lendingAdapter.convertCollateralToDebtAsset(state.collateral) - state.debt,
                sharesTotalSupply: state.sharesTotalSupply
            })
        );
    }
}
