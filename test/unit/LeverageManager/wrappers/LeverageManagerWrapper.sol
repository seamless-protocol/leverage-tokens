// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FeeManagerHarness} from "test/unit/FeeManager/wrappers/FeeManagerHarness.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerWrapper is LeverageManager, FeeManagerHarness {
    function calculateDebtAndShares(address strategy, ILendingAdapter lendingAdapter, uint256 collateral)
        external
        view
        returns (uint256 debt, uint256 shares)
    {
        return _calculateDebtAndShares(strategy, lendingAdapter, collateral);
    }

    function chargeStrategyFeeAndMintShares(address strategy, address recipient, uint256 debt, uint256 collateral)
        external
        returns (uint256)
    {
        return _chargeStrategyFeeAndMintShares(strategy, recipient, debt, collateral);
    }

    function convertToShares(address strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }

    function convertToEquity(address strategy, uint256 shares) external view returns (uint256 equity) {
        return _convertToEquity(strategy, shares);
    }

    function mintShares(address strategy, address recipient, uint256 shares) external {
        _mintShares(strategy, recipient, shares);
    }

    function calculateExcessOfCollateral(address strategy, ILendingAdapter lendingAdapter)
        external
        view
        returns (uint256 excessCollateral)
    {
        return _calculateExcessOfCollateral(strategy, lendingAdapter);
    }

    function calculateDebtToCoverEquity(address strategy, ILendingAdapter lendingAdapter, uint256 equity)
        external
        view
        returns (uint256 debt)
    {
        return _calculateDebtToCoverEquity(strategy, lendingAdapter, equity);
    }
}
