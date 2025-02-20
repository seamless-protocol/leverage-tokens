// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
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

    function exposed_computeFeeAdjustedShares(IStrategy strategy, uint256 amount, ExternalAction action)
        external
        view
        returns (uint256 amountAfterFee)
    {
        return _computeFeeAdjustedShares(strategy, amount, action);
    }
}
