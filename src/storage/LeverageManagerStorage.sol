// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library LeverageManagerStorage {
    /// @dev Struct that contains all core immutable strategy parameters
    struct StrategyCore {
        /// @dev Collateral asset on the lending pool
        address collateral;
        /// @dev Debt asset on the lending pool
        address debt;
        /// @dev Lending pool that strategy is deployed on top of
        address lendingPool;
    }

    /// @dev Struct that contains all strategy config related with leverage/rebalance
    struct LeverageConfig {
        /// @dev Minimum leverage allowed for strategy before triggering rebalance on 8 decimals
        uint256 minForRebalance;
        /// @dev Maximum leverage allowed for strategy before triggering rebalance on 8 decimals
        uint256 maxForRebalance;
        /// @dev Target leverage of the strategy on 8 decimals
        uint256 target;
    }

    /// @dev Struct that contains entire strategy config
    struct StrategyConfig {
        /// @dev Struct that contains core config of the strategy
        /// @dev This is configured when strategy is created and can not be changed after
        StrategyCore core;
        /// @dev Cap of the strategy, leveraged amount that can be changed
        uint256 cap;
        /// @dev Leverage config of the strategy that can be changed in order to make strategy more efficient
        LeverageConfig leverageConfig;
    }

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct Layout {
        /// @dev Strategy address => Config for strategy
        mapping(address strategy => StrategyConfig) config;
    }

    // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant STORAGE_SLOT = 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600;

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
