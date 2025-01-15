// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract ConvertCollateralToDebtAsset is MorphoLendingAdapterBaseTest {
    function test_convertCollateralToDebtAsset() public view {
        assertEq(lendingAdapter.convertCollateralToDebtAsset(0), block.timestamp);
    }
}
