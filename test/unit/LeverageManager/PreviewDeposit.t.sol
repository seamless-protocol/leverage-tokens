// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {DepositTest} from "./Deposit.t.sol";

contract PreviewActionTest is DepositTest {
    function test_previewAction_WithFee() public {
        _setStrategyActionFee(strategy, ExternalAction.Deposit, 0.05e4); // 5% fee
        _setStrategyActionFee(strategy, ExternalAction.Withdraw, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equity = 10 ether;
        (uint256 collateral, uint256 debt, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        assertEq(collateral, 19 ether - 1);
        assertEq(debt, 19 ether - 1);
        assertEq(expectedShares, 19 ether - 1);
        assertEq(sharesFee, 1 ether);

        (collateral, debt, expectedShares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 19 ether - 1);
        assertEq(debt, 19 ether - 1);
        assertEq(expectedShares, 19 ether - 1);
        assertEq(sharesFee, 1 ether);
    }

    function test_previewAction_WithoutFee() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equity = 10 ether;
        (uint256 collateral, uint256 debt, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        assertEq(collateral, 20 ether - 1);
        assertEq(debt, 10 ether - 1);
        assertEq(expectedShares, 20 ether - 1);
        assertEq(sharesFee, 0);

        (collateral, debt, expectedShares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 20 ether - 1);
        assertEq(debt, 10 ether - 1);
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

    function test_previewAction_ZeroSharesTotalSupply() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 2, debt: 1, sharesTotalSupply: 0});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equity = 1 ether;

        (uint256 collateral, uint256 debt, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Deposit);

        // Follows 2x target ratio
        assertEq(collateral, 2 ether);
        assertEq(debt, 1 ether);
        assertEq(shares, 0.5e18);
        assertEq(sharesFee, 0);

        (collateral, debt, shares, sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, ExternalAction.Withdraw);

        assertEq(collateral, 2 ether);
        assertEq(debt, 1 ether);
        assertEq(shares, 0.5e18);
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewAction(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equity,
        uint16 fee,
        uint8 actionNumber
    ) public {
        ExternalAction action = ExternalAction(actionNumber % 2); // Deposit or Withdraw
        fee = uint16(bound(fee, 0, leverageManager.MAX_FEE())); // 0% to 100% fee
        _setStrategyActionFee(strategy, action, fee);

        initialDebtInCollateralAsset =
            initialCollateral == 0 ? 0 : uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral - 1));

        if (initialCollateral == 0 && initialDebtInCollateralAsset == 0) {
            sharesTotalSupply = 0;
        } else {
            sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));
        }

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        equity = uint128(bound(equity, 1, type(uint96).max));

        (uint256 collateral, uint256 debt, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equity, action);

        StrategyState memory currentState = leverageManager.exposed_getStrategyState(strategy);
        if ((currentState.collateralInDebtAsset != 0 || currentState.debt != 0) && sharesTotalSupply != 0) {
            // If the strategy holds collateral or debt, then the collateral to add should be equal to the current
            // collateral ratio (minus some slippage due to rounding)
            uint256 newDebt = initialDebtInCollateralAsset + debt;
            uint256 newCollateral = initialCollateral + collateral;
            uint256 resultCollateralRatio = newDebt != 0 ? (newCollateral * _BASE_RATIO()) / newDebt : type(uint256).max;
            assertApproxEqRel(
                resultCollateralRatio,
                currentState.collateralRatio,
                _getAllowedCollateralRatioSlippage(initialDebtInCollateralAsset)
            );
        } else {
            // If the strategy does not hold any debt or collateral, then the deposit preview should use the target ratio
            // for determining how much collateral to add and how much debt to borrow
            assertEq(collateral * _BASE_RATIO() / debt, 2 * _BASE_RATIO());
        }

        uint256 sharesBeforeFee = equity * (sharesTotalSupply + 10 ** leverageManager.DECIMALS_OFFSET())
            / (uint256(initialCollateral) - initialDebtInCollateralAsset + 1);
        uint256 sharesFeeExpected = Math.mulDiv(sharesBeforeFee, fee, 1e4, Math.Rounding.Ceil);

        // Check that the shares to be minted are wrt the new equity being added to the strategy and the fee applied
        assertEq(sharesFee, sharesFeeExpected);
        assertEq(shares, sharesBeforeFee - sharesFee);
    }
}
