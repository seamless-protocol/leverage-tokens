// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {SwapAdapter} from "src/periphery/SwapAdapter.sol";

contract SwapAdapterHarness is SwapAdapter {
    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }
}
