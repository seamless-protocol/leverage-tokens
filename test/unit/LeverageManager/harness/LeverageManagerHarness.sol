// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerHarness is LeverageManager, FeeManagerHarness {
    function exposed_leverageManager_layoutSlot() external pure returns (bytes32 slot) {
        Storage.Layout storage $ = Storage.layout();

        assembly {
            slot := $.slot
        }
    }

    function exposed_calculateDebtAndShares(address strategy, ILendingAdapter lendingAdapter, uint256 assets)
        external
        view
        returns (uint256 collateral, uint256 debt, uint256 shares)
    {
        return _calculateCollateralDebtAndShares(strategy, lendingAdapter, assets);
    }

    function exposed_chargeStrategyFeeAndMintShares(
        address strategy,
        address recipient,
        uint256 debt,
        uint256 collateral
    ) external returns (uint256) {
        return _chargeStrategyFeeAndMintShares(strategy, recipient, debt, collateral);
    }

    function exposed_convertToShares(address strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }

    function exposed_mintShares(address strategy, address recipient, uint256 shares) external {
        _mintShares(strategy, recipient, shares);
    }
}
