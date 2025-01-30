// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ISwapper} from "src/interfaces/ISwapper.sol";

library SwapperStorage {
    /// @dev Struct containing all state for the Swapper contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.Swapper
    struct Layout {
        /// @dev LiFi Diamond Proxy protocol contract address
        address lifi;
        /// @dev Provider
        ISwapper.Provider provider;
    }

    function layout() internal pure returns (Layout storage l) {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.Swapper")) - 1)) & ~bytes32(uint256(0xff));
            l.slot := 0xd13913e6f5971fa78083bb454f0bd9d937359fbaf7a5296aa0498a9631cf8b00
        }
    }
}
