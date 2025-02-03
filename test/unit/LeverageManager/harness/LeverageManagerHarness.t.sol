// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {FeeManagerHarness} from "test/unit/FeeManager/harness/FeeManagerHarness.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {ActionType, RebalanceAction, TokenTransfer, StrategyState} from "src/types/DataTypes.sol";

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

    function exposed_getStrategyCollateralRatioAndExcess(IStrategy strategy, ILendingAdapter)
        external
        view
        returns (uint256 currCollateralRatio, int256 excessCollateral)
    {
        return _getStrategyCollateralRatioAndExcess(strategy);
    }

    function exposed_calculateCollateralAndDebtToCoverEquity(
        IStrategy strategy,
        ILendingAdapter,
        uint256 equity,
        IFeeManager.Action action
    ) external view returns (uint256 collateral, uint256 debt) {
        return _calculateCollateralAndDebtToCoverEquity(strategy, equity, action);
    }

    function exposed_validateRebalanceEligibility(IStrategy strategy, uint256 currRatio) external view {
        _validateRebalanceEligibility(strategy, currRatio);
    }

    function exposed_validateCollateralRatioAfterAction(
        IStrategy strategy,
        uint256 collateralRatioBefore,
        uint256 collateralRatioAfter
    ) external view {
        _validateCollateralRatioAfterAction(strategy, collateralRatioBefore, collateralRatioAfter);
    }

    function exposed_validateEquityChange(
        IStrategy strategy,
        StrategyState memory stateBefore,
        StrategyState memory stateAfter
    ) external view {
        _validateEquityChange(strategy, stateBefore, stateAfter);
    }

    function exposed_getStrategyState(IStrategy strategy) external view returns (StrategyState memory strategyState) {
        return _getStrategyState(strategy);
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

    function exposed_convertToEquity(IStrategy strategy, uint256 shares) external view returns (uint256 equity) {
        return _convertToEquity(strategy, shares);
    }

    function exposed_convertToShares(IStrategy strategy, uint256 equity) external view returns (uint256 shares) {
        return _convertToShares(strategy, equity);
    }
}
