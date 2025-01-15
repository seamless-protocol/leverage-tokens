// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetEquityInDebtAsset is MorphoLendingAdapterBaseTest {
    function test_getEquityInDebtAsset() public view {
        assertEq(lendingAdapter.getEquityInDebtAsset(), block.timestamp);
    }
}
