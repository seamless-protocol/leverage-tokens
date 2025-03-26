// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {MinMaxCollateralRatioRebalanceAdapter} from "src/rebalance/MinMaxCollateralRatioRebalanceAdapter.sol";

/// @notice Wrapper contract that exposes all internal functions of MinMaxCollateralRatioRebalanceAdapter
contract MinMaxCollateralRatioRebalanceAdapterHarness is MinMaxCollateralRatioRebalanceAdapter {
    function initialize(uint256 minCollateralRatio, uint256 maxCollateralRatio) external initializer {
        __MinMaxCollateralRatioRebalanceAdapter_init_unchained(minCollateralRatio, maxCollateralRatio);
    }

    function exposed_getMinMaxCollateralRatioRebalanceAdapterStorage() external pure returns (bytes32 slot) {
        MinMaxCollateralRatioRebalanceAdapterStorage storage $ = _getMinMaxCollateralRatioRebalanceAdapterStorage();

        assembly {
            slot := $.slot
        }
    }
}
