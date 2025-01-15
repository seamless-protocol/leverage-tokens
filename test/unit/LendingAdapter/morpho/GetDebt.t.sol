// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetDebt is MorphoLendingAdapterBaseTest {
    function test_getDebt() public view {
        assertEq(lendingAdapter.getDebt(), block.timestamp);
    }
}
