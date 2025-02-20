// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {console} from "forge-std/console.sol";
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

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityToAdd, ExternalAction.Deposit);

        assertEq(collateralToAdd, 20 ether - 1);
        assertEq(debtToBorrow, 10 ether - 1);
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

        _prepareLeverageManagerStateForDeposit(beforeState);

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

    function testFuzz_previewDeposit(
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

        console.log("1");

        initialDebtInCollateralAsset =
            initialCollateral == 0 ? 0 : uint128(bound(initialDebtInCollateralAsset, 0, initialCollateral - 1));

        console.log("2");

        if (initialCollateral == 0 && initialDebtInCollateralAsset == 0) {
            sharesTotalSupply = 0;
        } else {
            sharesTotalSupply = uint128(bound(sharesTotalSupply, 1, type(uint128).max));
        }

        console.log("3");

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: initialCollateral,
                debt: initialDebtInCollateralAsset, // 1:1 exchange rate for this test
                sharesTotalSupply: sharesTotalSupply
            })
        );

        console.log("4");

        // Ensure the collateral being added does not result in overflows due to mocked value sizes
        if (action == ExternalAction.Deposit) {
            equityInCollateralAsset = uint128(bound(equityInCollateralAsset, 1, type(uint96).max));
        } else {
            equityInCollateralAsset =
                uint128(bound(equityInCollateralAsset, 0, initialCollateral - initialDebtInCollateralAsset));
        }

        console.log("5");

        (uint256 collateral, uint256 debt, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewAction(strategy, equityInCollateralAsset, action);

        console.log("6");

        StrategyState memory currentState = leverageManager.exposed_getStrategyState(strategy);
        if (sharesTotalSupply != 0) {
            console.log("7");
            // If the strategy has shares, then the collateral should be equal to the current
            // collateral ratio (minus some slippage due to rounding)
            uint256 debtChangeInCollateralAsset = lendingAdapter.convertDebtToCollateralAsset(debt);

            console.log(initialDebtInCollateralAsset);
            console.log(debtChangeInCollateralAsset);

            uint256 newDebt = action == ExternalAction.Deposit
                ? initialDebtInCollateralAsset + debtChangeInCollateralAsset
                : initialDebtInCollateralAsset - debtChangeInCollateralAsset;
            uint256 newCollateral =
                action == ExternalAction.Deposit ? initialCollateral + collateral : initialCollateral - collateral;

            console.log("9");

            uint256 resultCollateralRatio = newDebt != 0 ? (newCollateral * _BASE_RATIO()) / newDebt : type(uint256).max;

            console.log("numbers");

            console.log(equityInCollateralAsset);
            console.log(initialCollateral);
            console.log(initialDebtInCollateralAsset);
            console.log(initialCollateral - initialDebtInCollateralAsset);

            console.log("new numbers");

            console.log(collateral);
            console.log(debt);

            if (action == ExternalAction.Withdraw && debt == initialDebtInCollateralAsset) {
                assertEq(resultCollateralRatio, type(uint256).max);
            } else {
                console.log("Nije full withdraw");
                console.log(resultCollateralRatio);
                console.log(currentState.collateralRatio);
                uint256 x = action == ExternalAction.Deposit ? initialDebtInCollateralAsset : newDebt;
                assertApproxEqRel(
                    resultCollateralRatio,
                    currentState.collateralRatio,
                    _getAllowedCollateralRatioSlippage(x),
                    "Collateral ratio after deposit should be within the allowed slippage"
                );
                assertGe(
                    resultCollateralRatio,
                    currentState.collateralRatio,
                    "Collateral ratio after deposit should be greater than or equal to before"
                );
            }
        } else {
            console.log("8");

            // If the strategy does not hold any debt or collateral, then the deposit preview should use the target ratio
            // for determining how much collateral to add and how much debt to borrow
            // assertEq(
            //     collateral * _BASE_RATIO() / debt, 2 * _BASE_RATIO(), "Collateral ratio after deposit should be 2x"
            // );
        }

        uint256 sharesBeforeFee = equityInCollateralAsset
            * (sharesTotalSupply + 10 ** leverageManager.DECIMALS_OFFSET())
            / (uint256(initialCollateral) - initialDebtInCollateralAsset + 1);
        uint256 sharesFeeExpected = Math.mulDiv(sharesBeforeFee, fee, 1e4, Math.Rounding.Ceil);

        // Check that the shares to be minted are wrt the new equity being added to the strategy and the fee applied
        // assertEq(sharesFee, sharesFeeExpected);
        // assertEq(shares, sharesBeforeFee - sharesFee);
    }
}
