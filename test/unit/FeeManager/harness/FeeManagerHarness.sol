// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManager} from "src/FeeManager.sol";

/// @notice Wrapper contract that exposes all internal functions ofFeeManager
contract FeeManagerHarness is FeeManager {
    function exposed_chargeStrategyFee(address strategy, uint256 amount, IFeeManager.Action action)
        external
        returns (uint256 amountAfterFee)
    {
        return _chargeStrategyFee(strategy, amount, action);
    }
}
