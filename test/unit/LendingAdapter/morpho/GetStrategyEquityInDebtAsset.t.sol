// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {MorphoLendingAdapterBaseTest} from "./MorphoLendingAdapterBase.t.sol";

contract GetStrategyEquityInDebtAsset is MorphoLendingAdapterBaseTest {
  function test_getStrategyEquityInDebtAsset() public {
    assertEq(lendingAdapter.getStrategyEquityInDebtAsset(address(0)), block.timestamp);
  }
}
