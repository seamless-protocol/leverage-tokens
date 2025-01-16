// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertCollateralToDebtAsset is MorphoLendingAdapterBaseTest {
    function test_convertCollateralToDebtAsset_RoundsDown() public {
        // Mock the price of the collateral asset in the debt asset to be 1 less than the scaling factor of Morpho oracles
        vm.mockCall(
            address(defaultMarketParams.oracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(ORACLE_PRICE_SCALE - 1)
        );

        // debt = collateral * collateralAssetPriceInDebtAsset / ORACLE_PRICE_SCALE
        // = 10 * (ORACLE_PRICE_SCALE - 1) / ORACLE_PRICE_SCALE
        // = 10 * (1e36 - 1) / 1e36
        // = 9 if rounded down
        assertEq(lendingAdapter.convertCollateralToDebtAsset(10), 9);
    }
}
