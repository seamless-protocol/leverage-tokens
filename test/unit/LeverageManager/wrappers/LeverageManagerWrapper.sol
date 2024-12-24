// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {FeeManagerHarness} from "test/unit/FeeManager/wrappers/FeeManagerHarness.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingContract} from "src/interfaces/ILendingContract.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerWrapper is LeverageManager, FeeManagerHarness {
    function calculateDebtAndShares(uint256 strategy, ILendingContract lendingContract, uint256 collateral)
        external
        view
        returns (uint256 debt, uint256 shares)
    {
        return _calculateDebtAndShares(strategy, lendingContract, collateral);
    }

    function chargeStrategyFeeAndMintShares(uint256 strategy, address recipient, uint256 debt, uint256 collateral)
        external
        returns (uint256)
    {
        return _chargeStrategyFeeAndMintShares(strategy, recipient, debt, collateral);
    }

    function convertToShares(uint256 strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }

    function convertToEquity(uint256 strategy, uint256 shares) external view returns (uint256 equity) {
        return _convertToEquity(strategy, shares);
    }

    function calculateExcessOfCollateral(uint256 strategy, ILendingContract lendingContract)
        external
        view
        returns (uint256 excessCollateral)
    {
        return _calculateExcessOfCollateral(strategy, lendingContract);
    }

    function calculateDebtToCoverEquity(uint256 strategy, ILendingContract lendingContract, uint256 equity)
        external
        view
        returns (uint256 debt)
    {
        return _calculateDebtToCoverEquity(strategy, lendingContract, equity);
    }

    function mint(uint256 strategy, address recipient, uint256 shares) external {
        _mint(recipient, strategy, shares);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(LeverageManager, AccessControlUpgradeable)
        returns (bool)
    {
        return LeverageManager.supportsInterface(interfaceId) || AccessControlUpgradeable.supportsInterface(interfaceId);
    }
}
