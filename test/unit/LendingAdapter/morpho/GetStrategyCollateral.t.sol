// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetStrategyCollateral is MorphoLendingAdapterBaseTest {
    function test_getStrategyCollateral() public {
      lendingAdapter.getStrategyCollateral(address(0));
  }

}
