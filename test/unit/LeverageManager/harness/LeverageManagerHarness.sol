// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// Internal imports
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {ERC6909Harness} from "test/unit/ERC6909/harness/ERC6909Harness.sol";
import {ERC6909} from "src/ERC6909.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerHarness is LeverageManager, FeeManagerHarness, ERC6909Harness {
    function exposed_leverageManager_layoutSlot() external pure returns (bytes32 slot) {
        Storage.Layout storage $ = Storage.layout();

        assembly {
            slot := $.slot
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(LeverageManager, AccessControlUpgradeable, ERC6909)
        returns (bool)
    {
        return LeverageManager.supportsInterface(interfaceId) || AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }

    function exposed_calculateCollateralDebtAndShares(
        uint256 strategyId,
        ILendingAdapter lendingAdapter,
        uint256 assets
    ) external view returns (uint256 collateral, uint256 debt, uint256 shares) {
        return _calculateCollateralDebtAndShares(strategyId, lendingAdapter, assets);
    }

    function exposed_chargeStrategyFeeAndMintShares(
        uint256 strategyId,
        address recipient,
        uint256 debt,
        uint256 collateral
    ) external returns (uint256) {
        return _chargeStrategyFeeAndMintShares(strategyId, recipient, debt, collateral);
    }

    function exposed_convertToShares(uint256 strategyId, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategyId, equity);
    }
}
