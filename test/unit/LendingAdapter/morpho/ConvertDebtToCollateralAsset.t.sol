// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertDebtToCollateralAsset is MorphoLendingAdapterBaseTest {
    function test_convertDebtToCollateralAsset_RoundsUp_EqualDebtAndCollateralDecimals() public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding up:
        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = debt * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = 1e18 * 1e36 / (1e36 - 1)
        // = 1e18 + 1, if rounded up. If rounded down, the result would be 1e18.
        uint256 debt = 1e18;
        uint256 price = ORACLE_PRICE_SCALE - 1;

        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(6);
        debtToken.mockSetDecimals(6);

        assertEq(lendingAdapter.convertDebtToCollateralAsset(debt), debt + 1);
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertDebtToCollateralAsset_RoundsUp_EqualDebtAndCollateralDecimals(uint128 debt) public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding up:
        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = debt * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = debt * 1e36 / (1e36 - 1)
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        assertEq(
            lendingAdapter.convertDebtToCollateralAsset(debt),
            Math.mulDiv(debt, ORACLE_PRICE_SCALE, price, Math.Rounding.Ceil)
        );
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertDebtToCollateralAsset_RoundsUp_CollateralDecimalsGreaterThanDebtDecimals(uint128 debt)
        public
    {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding up:
        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = debt * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = debt * 1e36 / (1e36 - 1)
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(18);
        debtToken.mockSetDecimals(6);
        uint256 scalingFactor = 10 ** (18 - 6);

        assertEq(
            lendingAdapter.convertDebtToCollateralAsset(debt),
            Math.mulDiv(debt * scalingFactor, ORACLE_PRICE_SCALE, price, Math.Rounding.Ceil)
        );
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertDebtToCollateralAsset_RoundsUp_DebtDecimalsGreaterThanCollateralDecimals(uint128 debt)
        public
    {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding up:
        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = debt * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = debt * 1e36 / (1e36 - 1)
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(6);
        debtToken.mockSetDecimals(18);
        uint256 scalingFactor = 10 ** (18 - 6);

        assertEq(
            lendingAdapter.convertDebtToCollateralAsset(debt),
            Math.mulDiv(debt, ORACLE_PRICE_SCALE, price * scalingFactor, Math.Rounding.Ceil)
        );
    }
}
