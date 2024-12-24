// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IFeeManager} from "src/interfaces/IFeeManager.sol";

library FeeManagerStorage {
    /// @dev Struct containing all state for the FeeManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.FeeManager
    struct Layout {
        /// @dev Treasury address that receives all the fees
        address treasury;
        /// @dev Strategy address => Action => Fee
        mapping(uint256 strategy => mapping(IFeeManager.Action => uint256)) strategyActionFee;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
