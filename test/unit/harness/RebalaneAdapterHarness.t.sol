// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";

contract RebalanceAdapterHarness is RebalanceAdapter {
    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }
}
