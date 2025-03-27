// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorphoBase, Market} from "@morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetHealthFactor is MorphoLendingAdapterBaseTest {
    function test_getHealthFactor() public {
        uint256 collateral = 5e6;
        uint256 borrowShares = 10e6;

        // Mock the price of the collateral asset in the debt asset to be 1:1 for simplicity
        uint256 price = ORACLE_PRICE_SCALE;
        vm.mockCall(
            address(defaultMarketParams.oracle), abi.encodeWithSelector(IOracle.price.selector), abi.encode(price)
        );

        // MorphoLib, used by MorphoLendingAdapter, calls Morpho.extSloads to get the position's collateral
        bytes32[] memory collateralReturnValue = new bytes32[](2);
        collateralReturnValue[0] = bytes32(uint256(collateral << 128));

        // MorphoBalancesLib, used by MorphoLendingAdapter, calls Morpho.extSloads to get the lendingAdapter's amount of borrow shares
        uint256[] memory borrowSharesReturnValue = new uint256[](1);
        borrowSharesReturnValue[0] = borrowShares;

        bytes[] memory mocks = new bytes[](2);
        mocks[0] = abi.encode(borrowSharesReturnValue);
        mocks[1] = abi.encode(collateralReturnValue);

        vm.mockCalls(address(morpho), abi.encodeWithSelector(IMorphoBase.extSloads.selector), mocks);

        // Mocking call to Morpho made in MorphoBalancesLib to get the market's total borrow assets and shares, which is how MorphoBalancesLib
        // calculates the exchange rate between borrow shares and borrow assets
        Market memory market = Market({
            totalSupplyAssets: 0, // Doesn't matter for this test
            totalSupplyShares: 0, // Doesn't matter for this test
            totalBorrowAssets: uint128(collateral / 2),
            totalBorrowShares: uint128(borrowShares),
            lastUpdate: uint128(block.timestamp), // Set to the current block timestamp to reduce test complexity (used for accruing interest in MorphoBalancesLib)
            fee: 0 // Set to 0 to reduce test complexity (used for accruing interest in MorphoBalancesLib)
        });
        morpho.mockSetMarket(defaultMarketId, market);

        // Not exactly 2 because of virtual assets and shares used in morpho's SharesMathLib
        assertEq(lendingAdapter.getHealthFactor(), 2199998328001270719);
    }
}
