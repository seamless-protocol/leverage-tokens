// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetCollateralInDebtAsset is MorphoLendingAdapterBaseTest {
    function test_getCollateralInDebtAsset() public view {
        assertEq(lendingAdapter.getCollateralInDebtAsset(), block.timestamp);
    }
}
