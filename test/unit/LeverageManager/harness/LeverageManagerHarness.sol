// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
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

    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }

    function exposed_getStrategyCollateralRatioAndExcess(IStrategy strategy, ILendingAdapter lendingAdapter)
        external
        view
        returns (uint256 currCollateralRatio, int256 excessCollateral)
    {
        return _getStrategyCollateralRatioAndExcess(strategy, lendingAdapter);
    }

    function exposed_calculateCollateralAndDebtToCoverEquity(
        IStrategy strategy,
        uint256 equityInDebtAsset,
        IFeeManager.Action action
    ) external view returns (uint256 collateral, uint256 debt) {
        return _calculateCollateralAndDebtToCoverEquity(strategy, equityInDebtAsset, action);
    }

    function exposed_convertToEquity(IStrategy strategy, uint256 shares) external view returns (uint256 equity) {
        return _convertToEquity(strategy, shares);
    }

    function exposed_convertToShares(IStrategy strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }
}
