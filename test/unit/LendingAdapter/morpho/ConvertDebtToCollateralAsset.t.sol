// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertDebtToCollateralAsset is MorphoLendingAdapterBaseTest {
    function test_convertDebtToCollateralAsset_RoundsUp() public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles
        vm.mockCall(
            address(defaultMarketParams.oracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(ORACLE_PRICE_SCALE - 1)
        );

        // collateral = debt * ORACLE_PRICE_SCALE / collateralAssetPriceInDebtAsset
        // = 10 * ORACLE_PRICE_SCALE / (ORACLE_PRICE_SCALE - 1)
        // = 10 * 1e36 / (1e36 - 1)
        // = 11 if rounded up
        assertEq(lendingAdapter.convertDebtToCollateralAsset(10), 11);
    }
}
