// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {FeeManagerStorage} from "src/storage/FeeManagerStorage.sol";

/// @notice Wrapper contract that exposes all internal functions ofFeeManager
contract FeeManagerHarness is FeeManager {
    function exposed_feeManager_layoutSlot() external pure returns (bytes32 slot) {
        FeeManagerStorage.Layout storage $ = FeeManagerStorage.layout();

        assembly {
            slot := $.slot
        }
    }

    function exposed_computeFeeAdjustedShares(IStrategy strategy, uint256 amount, IFeeManager.Action action)
        external
        view
        returns (uint256 amountAfterFee)
    {
        return _computeFeeAdjustedShares(strategy, amount, action);
    }

    function exposed_computeSharesBeforeFeeAdjustment(
        IStrategy strategy,
        uint256 feeAdjustedShares,
        IFeeManager.Action action
    ) external view returns (uint256 sharesBeforeFeeAdjustment) {
        return _computeSharesBeforeFeeAdjustment(strategy, feeAdjustedShares, action);
    }
}
