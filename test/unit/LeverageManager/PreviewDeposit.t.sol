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
            leverageManager.previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 20 ether);
        assertEq(debtToBorrow, 20 ether);
        assertEq(expectedShares, 19 ether - 1); // - 1 because of equity offset in convertToShares denominator
        assertEq(sharesFee, 1 ether);
    }

    function test_previewDeposit_WithoutFee() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 50 ether, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAdd = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 expectedShares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAdd);

        assertEq(collateralToAdd, 20 ether);
        assertEq(debtToBorrow, 10 ether);
        assertEq(expectedShares, 20 ether - 1); // 20 ether - 1 because of equity offset in convertToShares
        assertEq(sharesFee, 0);
    }

    function testFuzz_previewDeposit(
        uint128 initialCollateral,
        uint128 initialDebtInCollateralAsset,
        uint128 sharesTotalSupply,
        uint128 equityToAddInCollateralAsset,
        uint16 fee
    ) public {
        equityToAddInCollateralAsset = uint128(bound(equityToAddInCollateralAsset, 1, type(uint128).max));

        fee = uint16(bound(fee, 0, 1e4)); // 0% to 100% fee
        _setStrategyActionFee(strategy, IFeeManager.Action.Deposit, fee);

        {
            if (initialCollateral == 1) {
                initialDebtInCollateralAsset = 0;
            } else {
                uint256 minCollateralRatio = _BASE_RATIO() + 1;
                uint256 maxCollateralRatio = 3 * _BASE_RATIO();

                uint256 maxInitialDebtInCollateralAsset =
                    Math.mulDiv(initialCollateral, _BASE_RATIO(), minCollateralRatio, Math.Rounding.Floor);
                uint256 minInitialDebtInCollateralAsset =
                    Math.mulDiv(initialCollateral, _BASE_RATIO(), maxCollateralRatio, Math.Rounding.Ceil);
                initialDebtInCollateralAsset = uint128(
                    bound(
                        initialDebtInCollateralAsset, minInitialDebtInCollateralAsset, maxInitialDebtInCollateralAsset
                    )
                );
            }
        }

        _prepareLeverageManagerStateForDeposit(
            MockLeverageManagerStateForDeposit({
                collateral: initialCollateral,
                debt: lendingAdapter.convertCollateralToDebtAsset(initialDebtInCollateralAsset),
                sharesTotalSupply: sharesTotalSupply
            })
        );

        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        uint256 currentCollateralRatio = leverageManager.exposed_getStrategyState(strategy).collateralRatio;

        if (currentCollateralRatio != type(uint256).max) {
            // If the current collateral ratio is not `type(uint256).max` (there is debt held by the strategy),
            // we check that the collateral ratio of the new state is within the allowed slippage
            uint256 resultCollateralRatio =
                ((initialCollateral + collateralToAdd) * _BASE_RATIO()) / (initialDebtInCollateralAsset + debtToBorrow);
            assertApproxEqRel(
                resultCollateralRatio, currentCollateralRatio, _getAllowedCollateralRatioSlippage(initialCollateral)
            );
        } else {
            // If the current collateral ratio is `type(uint256).max`, then the previewed deposiit should use the target
            // ratio of the strategy
            assertApproxEqRel(
                collateralToAdd * _BASE_RATIO() / debtToBorrow,
                2 * _BASE_RATIO(),
                _getAllowedCollateralRatioSlippage(collateralToAdd)
            );
        }

        uint256 sharesBeforeFee = equityToAddInCollateralAsset
            * (sharesTotalSupply + 10 ** leverageManager.DECIMALS_OFFSET())
            / (initialCollateral - initialDebtInCollateralAsset + 1);
        uint256 sharesFeeExpected = Math.mulDiv(sharesBeforeFee, fee, 1e4, Math.Rounding.Ceil);

        // Check that the shares to be minted are wrt the new equity being added to the strategy and the fee applied
        assertEq(sharesFee, sharesFeeExpected);
        assertEq(shares, sharesBeforeFee - sharesFee);
    }

    function test_previewDeposit_CurrentCollateralRatioIsMax() public {
        MockLeverageManagerStateForDeposit memory beforeState =
            MockLeverageManagerStateForDeposit({collateral: 100 ether, debt: 0, sharesTotalSupply: 100 ether});

        _prepareLeverageManagerStateForDeposit(beforeState);

        uint256 equityToAddInCollateralAsset = 10 ether;
        (uint256 collateralToAdd, uint256 debtToBorrow, uint256 shares, uint256 sharesFee) =
            leverageManager.previewDeposit(strategy, equityToAddInCollateralAsset);

        // Current collateral ratio is max, so the target ratio is used (2x)
        assertEq(debtToBorrow, 10 ether);
        assertEq(collateralToAdd, 20 ether);
        assertEq(shares, 10 ether);
        assertEq(sharesFee, 0);
    }
}
