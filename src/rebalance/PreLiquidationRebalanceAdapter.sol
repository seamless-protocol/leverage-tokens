// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
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
        /// @notice Health factor threshold to allow rebalance
        uint256 healthFactorThreshold;
        /// @notice Rebalance reward, flat percentage that rebalancer can take from equity of the leverage token position
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

    function __PreLiquidationRebalanceAdapter_init(uint256 healthFactorThreshold, uint256 rebalanceReward)
        internal
        onlyInitializing
    {
        _getPreLiquidationRebalanceAdapterStorage().healthFactorThreshold = healthFactorThreshold;
        _getPreLiquidationRebalanceAdapterStorage().rebalanceReward = rebalanceReward;
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function getLeverageManager() public view virtual returns (ILeverageManager);

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function getHealthFactorThreshold() public view returns (uint256) {
        return _getPreLiquidationRebalanceAdapterStorage().healthFactorThreshold;
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
        ILeverageManager leverageManager = getLeverageManager();
        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(token);

        uint256 liquidationPenalty = lendingAdapter.getLiquidationPenalty();
        uint256 rebalanceRewardPercentage = Math.mulDiv(liquidationPenalty, getRebalanceReward(), REWARD_BASE);
        uint256 maxEquityLoss = Math.mulDiv(stateBefore.equity, rebalanceRewardPercentage, 1e18);

        LeverageTokenState memory stateAfter = leverageManager.getLeverageTokenState(token);
        return stateAfter.equity >= stateBefore.equity - maxEquityLoss;
    }

    /// @inheritdoc IPreLiquidationRebalanceAdapter
    function isEligibleForRebalance(ILeverageToken token, LeverageTokenState memory, address)
        public
        view
        virtual
        returns (bool)
    {
        IMorphoLendingAdapter lendingAdapter =
            IMorphoLendingAdapter(address(getLeverageManager().getLeverageTokenLendingAdapter(token)));
        uint256 healthFactorThreshold = getHealthFactorThreshold();
        uint256 currentHealthFactor = lendingAdapter.getHealthFactor();

        return currentHealthFactor <= healthFactorThreshold;
    }
}
