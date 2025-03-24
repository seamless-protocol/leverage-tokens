// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {
    ActionData,
    ActionType,
    ExternalAction,
    RebalanceAction,
    TokenTransfer,
    StrategyState
} from "src/types/DataTypes.sol";

/// @notice Wrapper contract that exposes all internal functions of LeverageManager
contract LeverageManagerHarness is LeverageManager, FeeManagerHarness {
    function exposed_getLeverageManagerStorageSlot() external pure returns (bytes32 slot) {
        LeverageManager.LeverageManagerStorage storage $ = _getLeverageManagerStorage();

        assembly {
            slot := $.slot
        }
    }

    function exposed_authorizeUpgrade(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
    }

    function exposed_isElementInSlice(RebalanceAction[] calldata actions, IStrategy strategy, uint256 untilIndex)
        external
        pure
        returns (bool)
    {
        return _isElementInSlice(actions, strategy, untilIndex);
    }

    function exposed_transferTokens(TokenTransfer[] calldata transfers, address from, address to) external {
        _transferTokens(transfers, from, to);
    }

    function exposed_executeLendingAdapterAction(IStrategy strategy, ActionType actionType, uint256 amount) external {
        _executeLendingAdapterAction(strategy, actionType, amount);
    }

    function exposed_convertToShares(IStrategy strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }

    function exposed_previewAction(IStrategy strategy, uint256 equityInCollateralAsset, ExternalAction action)
        external
        view
        returns (ActionData memory)
    {
        return _previewAction(strategy, equityInCollateralAsset, action);
    }

    function exposed_computeCollateralAndDebtForAction(
        IStrategy strategy,
        uint256 equityInCollateralAsset,
        ExternalAction action
    ) external view returns (uint256 collateral, uint256 debt) {
        return _computeCollateralAndDebtForAction(strategy, equityInCollateralAsset, action);
    }
}
