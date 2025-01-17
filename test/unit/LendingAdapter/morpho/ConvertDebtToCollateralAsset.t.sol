// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertDebtToCollateralAsset is MorphoLendingAdapterBaseTest {
    /// @dev uint128 is used to avoid overflows in the test. Also, Morpho only supports up to type(uint128).max for debt and collateral
    function testFuzz_convertDebtToCollateralAsset_RoundsUp(uint128 debt) public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles
        vm.mockCall(
            address(defaultMarketParams.oracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(ORACLE_PRICE_SCALE - 1)
        );

        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = debt * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = debt * 1e36 / (1e36 - 1)
        assertEq(
            lendingAdapter.convertDebtToCollateralAsset(debt),
            Math.mulDiv(debt, ORACLE_PRICE_SCALE, ORACLE_PRICE_SCALE - 1, Math.Rounding.Ceil)
        );
    }
}
