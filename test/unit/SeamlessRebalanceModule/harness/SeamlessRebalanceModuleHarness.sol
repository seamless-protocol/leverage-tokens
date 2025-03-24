// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SeamlessRebalanceModule} from "src/rebalance/SeamlessRebalanceModule.sol";

/// @notice Wrapper contract that exposes all internal functions of SeamlessRebalanceModule
contract SeamlessRebalanceModuleHarness is SeamlessRebalanceModule {
    function exposed_getSeamlessRebalanceModuleStorage() external pure returns (bytes32 slot) {
        SeamlessRebalanceModuleStorage storage $ = _getSeamlessRebalanceModuleStorage();

        assembly {
            slot := $.slot
        }
    }

    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }
}
