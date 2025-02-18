// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {IRebalanceWhitelist} from "src/interfaces/IRebalanceWhitelist.sol";
import {IRebalanceProfitDistributor} from "src/interfaces/IRebalanceProfitDistributor.sol";

library LeverageManagerStorage {
    /// @dev Struct that contains entire strategy config
    struct StrategyConfig {
        /// @dev Lending adapter for strategy
        ILendingAdapter lendingAdapter;
        /// @dev Cap of the strategy, leveraged amount that can be changed
        uint256 collateralCap;
        /// @dev Minimum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        ///      Collateral ratio is calculated as collateral value / debt value
        uint256 minCollateralRatio;
        /// @dev Maximum collateral ratio allowed for strategy before triggering rebalance on 8 decimals
        uint256 maxCollateralRatio;
        /// @dev Target collateral ratio of the strategy on 8 decimals
        uint256 targetCollateralRatio;
        /// @dev Rebalance reward distributor module for strategy
        IRebalanceProfitDistributor rebalanceProfitDistributor;
        /// @dev Whitelist module for strategy, if not set rebalance is open for everybody
        IRebalanceWhitelist rebalanceWhitelist;
    }

    /// @dev Struct containing all state for the LeverageManager contract
    /// @custom:storage-location erc7201:seamless.contracts.storage.LeverageManager
    struct Layout {
        /// @dev Factory for deploying new strategy tokens when creating new strategies
        IBeaconProxyFactory strategyTokenFactory;
        /// @dev Strategy address => Config for strategy
        mapping(IStrategy strategy => StrategyConfig) config;
        /// @dev Lending adapter address => Is lending adapter registered. Two strategies can't have same lending adapter
        mapping(address lendingAdapter => bool) isLendingAdapterUsed;
    }

    function layout() internal pure returns (Layout storage l) {
        assembly {
            // keccak256(abi.encode(uint256(keccak256("seamless.contracts.storage.LeverageManager")) - 1)) & ~bytes32(uint256(0xff));
            l.slot := 0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600
        }
    }
}
