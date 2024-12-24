// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILendingContract} from "src/interfaces/ILendingContract.sol";

library LeverageManagerStorage {
    /// @dev Struct that contains all core immutable strategy parameters
    struct StrategyCore {
        /// @dev Collateral asset on the lending pool
        address collateral;
        /// @dev Debt asset on the lending pool
        address debt;
    }

    /// @dev Struct that contains all strategy config related with leverage/rebalance
    struct CollateralRatios {
        /// @dev Minimum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        ///      Collateral ratio is calculated as collateral value / debt value
        uint256 minForRebalance;
        /// @dev Maximum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        uint256 maxForRebalance;
        /// @dev Target collateral ratio of the strategy on 8 decimals
        uint256 target;
    }

    /// @dev Struct that contains entire strategy config
    struct StrategyConfig {
        /// @dev Struct that contains core config of the strategy.
        ///      This is configured when strategy is created and can not be changed after
        StrategyCore core;
        /// @dev Leverage config of the strategy that can be changed in order to make strategy more efficient
        CollateralRatios collateralRatios;
        /// @dev Cap of the strategy, leveraged amount that can be changed
        uint256 cap;
    }

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct Layout {
        /// @dev Strategy address => Config for strategy
        mapping(address strategy => StrategyConfig) config;
        /// @dev Strategy address => Adapter address for lending pool
        mapping(address strategy => ILendingContract) lendingAdapter;
        /// @dev Strategy address => Total shares in circulation
        mapping(address strategy => uint256) totalShares;
        /// @dev Strategy address => User address => Shares that user owns
        mapping(address strategy => mapping(address user => uint256)) userStrategyShares;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)
    ) & ~bytes32(uint256(0xff));

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
