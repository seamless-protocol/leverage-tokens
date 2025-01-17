// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorphoBase, Market} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetEquityInDebtAsset is MorphoLendingAdapterBaseTest {
    function test_getEquityInDebtAsset() public {
        uint128 collateral = 10;
        uint128 borrowShares = 5e6;

        // Mocking call to Morpho made in MorphoStorageLib to get the position's borrow shares and collateral
        bytes32[] memory returnValue = new bytes32[](2);
        returnValue[0] = bytes32((uint256(collateral) << 128) | uint256(borrowShares));
        vm.mockCall(address(morpho), abi.encodeWithSelector(IMorphoBase.extSloads.selector), abi.encode(returnValue));

        // Mocking call to Morpho made in MorphoBalancesLib to get the market's total borrow assets and shares
        Market memory market = Market({
            totalSupplyAssets: 0, // Doesn't matter for this test
            totalSupplyShares: 0, // Doesn't matter for this test
            totalBorrowAssets: 5,
            totalBorrowShares: borrowShares,
            lastUpdate: uint128(block.timestamp), // Set to the current block timestamp to reduce test complexity (used for accruing interest in MorphoBalancesLib)
            fee: 0 // Set to 0 to reduce test complexity (used for accruing interest in MorphoBalancesLib)
        });
        morpho.mockSetMarket(defaultMarketId, market);

        // Mock the price of the collateral asset in the debt asset to be 1:2
        vm.mockCall(
            address(defaultMarketParams.oracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(ORACLE_PRICE_SCALE * 2)
        );

        uint256 expectedCollateralInDebtAsset = collateral * 2;
        assertEq(lendingAdapter.getEquityInDebtAsset(), expectedCollateralInDebtAsset - market.totalBorrowAssets);
    }
}
