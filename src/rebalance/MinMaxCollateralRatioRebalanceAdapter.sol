// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {IMinMaxCollateralRatioRebalanceAdapter} from "src/interfaces/IMinMaxCollateralRatioRebalanceAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";

abstract contract MinMaxCollateralRatioRebalanceAdapter is IMinMaxCollateralRatioRebalanceAdapter, Initializable {
    /// @dev Struct containing all state for the MinMaxCollateralRatioRebalanceAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.MinMaxCollateralRatioRebalanceAdapter
    struct MinMaxCollateralRatioRebalanceAdapterStorage {
        /// @dev Minimum collateral ratio for a leverage token, immutable
        uint256 minCollateralRatio;
        /// @dev Maximum collateral ratio for a leverage token, immutable
        uint256 maxCollateralRatio;
    }

    function _getMinMaxCollateralRatioRebalanceAdapterStorage()
        internal
        pure
        returns (MinMaxCollateralRatioRebalanceAdapterStorage storage $)
    {
        // slither-disable-next-line assembly
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.MinMaxCollateralRatioRebalanceAdapter")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0x1c10b3efa82760c6584510ab37216b4b9605559cde452f64514c8bd3d1681600
        }
    }

    function __MinMaxCollateralRatioRebalanceAdapter_init_unchained(
        uint256 minCollateralRatio,
        uint256 maxCollateralRatio
    ) internal onlyInitializing {
        if (minCollateralRatio > maxCollateralRatio) {
            revert MinCollateralRatioTooHigh();
        }

        _getMinMaxCollateralRatioRebalanceAdapterStorage().minCollateralRatio = minCollateralRatio;
        _getMinMaxCollateralRatioRebalanceAdapterStorage().maxCollateralRatio = maxCollateralRatio;

        emit MinMaxCollateralRatioRebalanceAdapterInitialized(minCollateralRatio, maxCollateralRatio);
    }

    /// @inheritdoc IMinMaxCollateralRatioRebalanceAdapter
    function getLeverageTokenMinCollateralRatio() public view returns (uint256) {
        return _getMinMaxCollateralRatioRebalanceAdapterStorage().minCollateralRatio;
    }

    /// @inheritdoc IMinMaxCollateralRatioRebalanceAdapter
    function getLeverageTokenMaxCollateralRatio() public view returns (uint256) {
        return _getMinMaxCollateralRatioRebalanceAdapterStorage().maxCollateralRatio;
    }

    function isEligibleForRebalance(ILeverageToken, LeverageTokenState memory state, address)
        public
        view
        virtual
        returns (bool isEligible)
    {
        uint256 minCollateralRatio = getLeverageTokenMinCollateralRatio();
        uint256 maxCollateralRatio = getLeverageTokenMaxCollateralRatio();

        if (state.collateralRatio >= minCollateralRatio && state.collateralRatio <= maxCollateralRatio) {
            return false;
        }

        return true;
    }

    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        public
        view
        virtual
        returns (bool isValid)
    {
        uint256 targetRatio = ILeverageManager(msg.sender).getLeverageTokenTargetCollateralRatio(token);
        LeverageTokenState memory stateAfter = ILeverageManager(msg.sender).getLeverageTokenState(token);

        uint256 ratioBefore = stateBefore.collateralRatio;
        uint256 ratioAfter = stateAfter.collateralRatio;

        uint256 minRatioAfter = ratioBefore > targetRatio ? targetRatio : ratioBefore;
        uint256 maxRatioAfter = ratioBefore > targetRatio ? ratioBefore : targetRatio;

        if (ratioAfter < minRatioAfter || ratioAfter > maxRatioAfter) {
            return false;
        }

        return true;
    }
}
