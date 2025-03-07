// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ExternalAction} from "src/types/DataTypes.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {FeeManager} from "src/FeeManager.sol";

/// @notice Wrapper contract that exposes all internal functions ofFeeManager
contract FeeManagerHarness is FeeManager {
    function exposed_getFeeManagerStorageSlot() external pure returns (bytes32 slot) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        assembly {
            slot := $.slot
        }
    }
}
