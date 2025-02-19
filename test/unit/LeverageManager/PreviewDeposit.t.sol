// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {StrategyState} from "src/types/DataTypes.sol";
import {DepositTest} from "./Deposit.t.sol";

contract PreviewDepositTest is DepositTest {
    function test_previewDeposit_WithFee() public {
        _setStrategyActionFee(strategy, IFeeManager.Action.Deposit, 0.05e4); // 5% fee

        // 1:2 exchange rate
        lendingAdapter.mockConvertCollateralToDebtAssetExchangeRate(2e8);

        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 100 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 19 ether - 1);
        assertEq(debtToBorrow, 19 ether - 1);
        assertEq(expectedShares, 19 ether - 1);
        assertEq(sharesFee, 1 ether);
        assertEq(leverageManager.exposed_convertToEquity(strategy, expectedShares), 19 ether - 1);
    }

    function test_previewDeposit_WithoutFee() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 20 ether - 1);
        assertEq(debtToBorrow, 10 ether - 1);
        assertEq(expectedShares, 20 ether - 1);
        assertEq(sharesFee, 0);
        assertEq(leverageManager.exposed_convertToEquity(strategy, expectedShares), 10 ether - 1);
    }

    function test_previewDeposit_ZeroEquityToAdd() public view {
        uint256 equityToAdd = 0;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.exposed_previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 0);
        assertEq(debtToBorrow, 0);
        assertEq(expectedShares, 0);
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewDeposit(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset,
        uint16 fee
    ) public {
        fee = uint16(bound(fee, 0, 1e4)); // 0% to 100% fee
        _setStrategyActionFee(strategy, IFeeManager.Action.Deposit, fee);

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
        equityToAddInCollateralAsset = uint128(bound(equityToAddInCollateralAsset, 1, type(uint96).max));

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewDeposit(strategy, equityToAddInCollateralAsset);

        StrategyState memory currentState = leverageManager.exposed_getStrategyState(strategy);
        if (currentState.collateralInDebtAsset != 0 || currentState.debt != 0) {
            if (currentState.debt == 0) {
                // If the strategy holds collateral but no debt, then the collateral to add should be equal to the equity
                assertEq(collateralToAdd, equityToAddInCollateralAsset);
                assertEq(debtToBorrow, 0);
            } else {
                // If the strategy holds both collateral and debt, then the collateral to add should be equal to the current
                // collateral ratio (minus some slippage due to rounding)
                uint256 resultCollateralRatio = ((initialCollateral + collateralToAdd) * _BASE_RATIO())
                    / (initialDebtInCollateralAsset + debtToBorrow);
                assertApproxEqRel(
                    resultCollateralRatio,
                    currentState.collateralRatio,
                    _getAllowedCollateralRatioSlippage(initialDebtInCollateralAsset)
                );
            }
        } else {
            // If the strategy does not hold any debt or collateral, then the deposit preview should use the target ratio
            // for determining how much collateral to add and how much debt to borrow
            assertEq(collateralToAdd * _BASE_RATIO() / debtToBorrow, 2 * _BASE_RATIO());
        }

        uint256 sharesBeforeFee = equityToAddInCollateralAsset
            * (sharesTotalSupply + 10 ** leverageManager.DECIMALS_OFFSET())
            / (uint256(initialCollateral) - initialDebtInCollateralAsset + 1);
        uint256 sharesFeeExpected = Math.mulDiv(sharesBeforeFee, fee, 1e4, Math.Rounding.Ceil);

        // Check that the shares to be minted are wrt the new equity being added to the strategy and the fee applied
        assertEq(sharesFee, sharesFeeExpected);
        assertEq(shares, sharesBeforeFee - sharesFee);
    }

    function test_previewDeposit_ZeroDebtInStrategy() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 0, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.exposed_previewDeposit(strategy, equityToAddInCollateralAsset);

        assertEq(debtToBorrow, 0);
        assertEq(collateralToAdd, 10 ether);
        assertEq(shares, 10 ether);
        assertEq(sharesFee, 0);
    }
}
