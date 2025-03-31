// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {IPreLiquidationRebalanceAdapter} from "src/interfaces/IPreLiquidationRebalanceAdapter.sol";

abstract contract PreLiquidationRebalanceAdapter is Initializable, IPreLiquidationRebalanceAdapter {
    /// @notice Reward base, 100_00 means that the reward is 100%
    uint256 public constant REWARD_BASE = 1e4;

    /// @dev Struct containing all state for the PreLiquidationRebalanceAdapter contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.PreLiquidationRebalanceAdapter
    struct PreLiquidationRebalanceAdapterStorage {
        /// @notice Collateral ratio threshold to allow rebalance
        uint256 collateralRatioThreshold;
        /// @notice Rebalance reward, flat percentage that rebalancer can take from equity
        /// @dev Percentage represents percentage of debt repaid that rebalancer can take from equity
        /// @dev 100_00 = 100%
        uint256 rebalanceReward;
    }

    function _getPreLiquidationRebalanceAdapterStorage()
        internal
        pure
        returns (PreLiquidationRebalanceAdapterStorage storage $)
    {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.PreLiquidationRebalanceAdapter")) - 1)) & ~bytes32(uint256(0xff));
            $.slot := 0xb16e43fdb4a23e2eb5ac7d6fe250e1e010c7a5096910e708d8b2faba66b7d800
        }
    }

    function __PreLiquidationRebalanceAdapter_init(uint256 collateralRatioThreshold, uint256 rebalanceReward)
        internal
        onlyInitializing
    {
        _getPreLiquidationRebalanceAdapterStorage().collateralRatioThreshold = collateralRatioThreshold;
        _getPreLiquidationRebalanceAdapterStorage().rebalanceReward = rebalanceReward;
        emit PreLiquidationRebalanceAdapterInitialized(collateralRatioThreshold, rebalanceReward);
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function getLeverageManager() public view virtual returns (ILeverageManager);

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function getCollateralRatioThreshold() public view returns (uint256) {
        return _getPreLiquidationRebalanceAdapterStorage().collateralRatioThreshold;
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function getRebalanceReward() public view returns (uint256) {
        return _getPreLiquidationRebalanceAdapterStorage().rebalanceReward;
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function isStateAfterRebalanceValid(ILeverageToken token, LeverageTokenState memory stateBefore)
        public
        view
        virtual
        returns (bool)
    {
        // If rebalance is now caused by leverage token being close to liquidation there is no reason for this adapter to check anything
        if (stateBefore.collateralRatio >= getCollateralRatioThreshold()) {
            return true;
        }

        ILeverageManager leverageManager = getLeverageManager();
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(token)));

        LeverageTokenState memory stateAfter = leverageManager.getLeverageTokenState(token);
        uint256 liquidationPenalty = lendingAdapter.getLiquidationPenalty();

        console.log("liquidationPenalty", liquidationPenalty);

        uint256 rebalanceRewardPercentage = Math.mulDiv(liquidationPenalty, getRebalanceReward(), REWARD_BASE);
        console.log("rebalanceRewardPercentage", rebalanceRewardPercentage);
        uint256 debtRepaid =
            stateBefore.debt > stateAfter.debt ? stateBefore.debt - stateAfter.debt : stateAfter.debt - stateBefore.debt;

        console.log("debtRepaid", debtRepaid);

        uint256 maxEquityLoss = Math.mulDiv(debtRepaid, rebalanceRewardPercentage, 1e18);
        console.log("max equity loss", maxEquityLoss);
        console.log("stateBefore.equity", stateBefore.equity);
        return stateAfter.equity >= stateBefore.equity - maxEquityLoss;
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory state, address)
        public
        view
        virtual
        returns (bool)
    {
        console.log("getCollateralRatioThreshold()", getCollateralRatioThreshold());
        console.log("state.collateralRAtio", state.collateralRatio);
        return state.collateralRatio < getCollateralRatioThreshold();
    }
}
