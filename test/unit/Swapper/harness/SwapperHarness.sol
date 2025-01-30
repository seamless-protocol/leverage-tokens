// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {Swapper} from "src/periphery/Swapper.sol";
import {SwapperStorage as Storage} from "src/storage/SwapperStorage.sol";

contract SwapperHarness is Swapper {
    function exposed_swapper_layoutSlot() external pure returns (bytes32 slot) {
        Storage.Layout storage $ = Storage.layout();

        assembly {
            slot := $.slot
        }
    }

    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }
}
