// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";

library LeverageManagerStorage {
    /// @dev Struct that contains all strategy config related with leverage/rebalance
    struct CollateralRatios {
        /// @dev Minimum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        ///      Collateral ratio is calculated as collateral value / debt value
        uint256 minCollateralRatio;
        /// @dev Maximum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        uint256 maxCollateralRatio;
        /// @dev Target collateral ratio of the strategy on 8 decimals
        uint256 targetCollateralRatio;
    }

    /// @dev Struct that contains entire strategy config
    struct StrategyConfig {
        /// @dev Collateral asset on the lending pool, immutable
        address collateralAsset;
        /// @dev Debt asset on the lending pool, immutable
        address debtAsset;
        /// @dev Lending adapter for strategy
        ILendingAdapter lendingAdapter;
        /// @dev Leverage config of the strategy that can be changed in order to make strategy more efficient
        CollateralRatios collateralRatios;
        /// @dev Cap of the strategy, leveraged amount that can be changed
        uint256 collateralCap;
    }

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct Layout {
        /// @dev Strategy address => Config for strategy
        mapping(address strategy => StrategyConfig) config;
        /// @dev Strategy address => Total shares in circulation
        mapping(address strategy => uint256) totalShares;
        /// @dev Strategy address => User address => Shares that user owns
        mapping(address strategy => mapping(address user => uint256)) userStrategyShares;
    }

    function layout() internal pure returns (Layout storage l) {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
            l.slot := 0x6c0d8f7f1305f10aa51c80093531513ff85a99140b414f68890d41ac36949e00
        }
    }
}
