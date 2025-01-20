// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertCollateralToDebtAsset is MorphoLendingAdapterBaseTest {
    function test_convertCollateralToDebtAsset_RoundsDown_EqualDebtAndCollateralDecimals() public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding down:
        // debt = collateral * collateralAssetPriceInDebtAsset / ORACLE_PRICE_SCALE
        // = collateral * (ORACLE_PRICE_SCALE - 1) / ORACLE_PRICE_SCALE
        // = 1e18 * (1e36 - 1) / 1e36
        // = 1e18 - 1, if rounded down. If rounded up, the result would be 1e18.
        uint256 collateral = 1e18;
        uint256 price = ORACLE_PRICE_SCALE - 1;

        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(6);
        debtToken.mockSetDecimals(6);

        assertEq(lendingAdapter.convertCollateralToDebtAsset(collateral), collateral - 1);
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertCollateralToDebtAsset_RoundsDown_EqualDebtAndCollateralDecimals(uint128 collateral)
        public
    {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding down:
        // debt = collateral * collateralAssetPriceInDebtAsset / ORACLE_PRICE_SCALE
        // = collateral * (ORACLE_PRICE_SCALE - 1) / ORACLE_PRICE_SCALE
        // = collateral * (1e36 - 1) / 1e36
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(6);
        debtToken.mockSetDecimals(6);

        assertEq(
            lendingAdapter.convertCollateralToDebtAsset(collateral),
            Math.mulDiv(collateral, price, ORACLE_PRICE_SCALE, Math.Rounding.Floor)
        );
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertCollateralToDebtAsset_RoundsDown_CollateralDecimalsGreaterThanDebtDecimals(
        uint128 collateral
    ) public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding down:
        // debt = collateral * collateralAssetPriceInDebtAsset / ORACLE_PRICE_SCALE
        // = collateral * (ORACLE_PRICE_SCALE - 1) / ORACLE_PRICE_SCALE
        // = collateral * (1e36 - 1) / 1e36
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(18);
        debtToken.mockSetDecimals(6);
        uint256 scalingFactor = 10 ** (18 - 6);

        assertEq(
            lendingAdapter.convertCollateralToDebtAsset(collateral),
            Math.mulDiv(collateral, price, ORACLE_PRICE_SCALE * scalingFactor, Math.Rounding.Floor)
        );
    }

    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertCollateralToDebtAsset_RoundsDown_DebtDecimalsGreaterThanCollateralDecimals(
        uint128 collateral
    ) public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles to simulate rounding down:
        // debt = collateral * collateralAssetPriceInDebtAsset / ORACLE_PRICE_SCALE
        // = collateral * (ORACLE_PRICE_SCALE - 1) / ORACLE_PRICE_SCALE
        uint256 price = ORACLE_PRICE_SCALE - 1;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        collateralToken.mockSetDecimals(6);
        debtToken.mockSetDecimals(18);
        uint256 scalingFactor = 10 ** (18 - 6);

        assertEq(
            lendingAdapter.convertCollateralToDebtAsset(collateral),
            Math.mulDiv(collateral * scalingFactor, price, ORACLE_PRICE_SCALE, Math.Rounding.Floor)
        );
    }
}
