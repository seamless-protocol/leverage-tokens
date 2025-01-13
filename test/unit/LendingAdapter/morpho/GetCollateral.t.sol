// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetCollateral is MorphoLendingAdapterBaseTest {
    function test_getCollateral() public view {
        lendingAdapter.getCollateral();
    }
}
