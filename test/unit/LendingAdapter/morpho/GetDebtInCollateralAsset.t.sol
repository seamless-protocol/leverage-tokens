// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorphoBase, Market} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetDebtInCollateralAsset is MorphoLendingAdapterBaseTest {
    function test_getDebtInCollateralAsset() public {
        uint256 borrowShares = 10e6;

        // MorphoBalancesLib, used by MorphoLendingAdapter, calls Morpho.extSloads to get the lendingAdapter's amount of borrow shares
        uint256[] memory returnValue = new uint256[](1);
        returnValue[0] = borrowShares;
        vm.mockCall(address(morpho), abi.encodeWithSelector(IMorphoBase.extSloads.selector), abi.encode(returnValue));

        // Mocking call to Morpho made in MorphoBalancesLib to get the market's total borrow assets and shares, which is how MorphoBalancesLib
        // calculates the exchange rate between borrow shares and borrow assets
        Market memory market = Market({
            totalSupplyAssets: 0, // Doesn't matter for this test
            totalSupplyShares: 0, // Doesn't matter for this test
            totalBorrowAssets: 10e18,
            totalBorrowShares: 14e6,
            lastUpdate: uint128(block.timestamp), // Set to the current block timestamp to reduce test complexity (used for accruing interest in MorphoBalancesLib)
            fee: 0 // Set to 0 to reduce test complexity (used for accruing interest in MorphoBalancesLib)
        });
        morpho.mockSetMarket(defaultMarketId, market);

        // Mock the price of the collateral asset in the debt asset to be 2:1
        vm.mockCall(
            address(defaultMarketParams.oracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(ORACLE_PRICE_SCALE / 2)
        );

        assertEq(
            lendingAdapter.getDebtInCollateralAsset(),
            // getDebt() calls MorphoBalancesLib.expectedBorrowAssets, which uses SharesMathLib.toAssetsUp, which uses
            // the market's total borrow assets and shares and virtual offsets
            Math.mulDiv(borrowShares, market.totalBorrowAssets + 1, market.totalBorrowShares + 1e6, Math.Rounding.Ceil)
                * 2
        );
    }
}
