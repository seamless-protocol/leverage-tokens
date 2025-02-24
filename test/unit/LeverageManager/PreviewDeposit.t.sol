// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console} from "forge-std/console.sol";
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
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

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

        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: initialCollateral, debt: initialDebt, sharesTotalSupply: 0});

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
            MockLeverageManagerStateForDeposit({
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
}
