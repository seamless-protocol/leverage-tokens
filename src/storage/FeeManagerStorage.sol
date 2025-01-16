// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IFeeManager} from "src/interfaces/IFeeManager.sol";

library FeeManagerStorage {
    /// @dev Struct containing all state for the FeeManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.FeeManager
    struct Layout {
        /// @dev Treasury address that receives all the fees
        address treasury;
        /// @dev Strategy address => Action => Fee
        mapping(IStrategy strategy => mapping(IFeeManager.Action => uint256)) strategyActionFee;
    }

    function layout() internal pure returns (Layout storage l) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
            l.slot := 0x6c0d8f7f1305f10aa51c80093531513ff85a99140b414f68890d41ac36949e00
        }
    }
}
