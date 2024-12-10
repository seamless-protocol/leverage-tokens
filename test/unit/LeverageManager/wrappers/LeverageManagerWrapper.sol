// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingContract} from "src/interfaces/ILendingContract.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerWrapper is LeverageManager {
    function calculateDebtAndShares(address strategy, ILendingContract lendingContract, uint256 collateral)
        external
        view
        returns (uint256 debt, uint256 shares)
    {
        return _calculateDebtAndShares(strategy, lendingContract, collateral);
    }

    function chargeStrategyFeeAndMintShares(address strategy, address recipient, uint256 debt, uint256 collateral)
        external
    {
        _chargeStrategyFeeAndMintShares(strategy, recipient, debt, collateral);
    }

    function convertToShares(address strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }

    function mintShares(address strategy, address recipient, uint256 shares) external {
        _mintShares(strategy, recipient, shares);
    }
}
