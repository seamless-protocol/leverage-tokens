// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {IMorphoLendingAdapter} from "../IMorphoLendingAdapter.sol";
import {IMorphoLendingAdapterFactory} from "../IMorphoLendingAdapterFactory.sol";
import {IRebalanceAdapter} from "../IRebalanceAdapter.sol";
import {ActionData} from "../../types/DataTypes.sol";

interface ILeverageTokenDeploymentBatcher {
    struct LeverageTokenDeploymentParams {
        /// @notice The name of the leverage token
        string leverageTokenName;
        /// @notice The symbol of the leverage token
        string leverageTokenSymbol;
        /// @notice The mint token action fee for the leverage token
        uint256 mintTokenFee;
        /// @notice The redeem token action fee for the leverage token
        uint256 redeemTokenFee;
    }

    struct MorphoLendingAdapterDeploymentParams {
        /// @notice The Morpho market ID for the lending adapter
        Id morphoMarketId;
        /// @notice The base salt for the lending adapter deployment
        bytes32 baseSalt;
    }

    struct RebalanceAdapterDeploymentParams {
        /// @notice The implementation address of the rebalance adapter
        address implementation;
        /// @notice The owner of the rebalance adapter
        address owner;
        /// @notice The minimum collateral ratio for the rebalance adapter
        uint256 minCollateralRatio;
        /// @notice The target collateral ratio for the rebalance adapter. Must be > `LeverageManager.BASE_RATIO()`
        uint256 targetCollateralRatio;
        /// @notice The maximum collateral ratio for the rebalance adapter
        uint256 maxCollateralRatio;
        /// @notice The duration of the auction for the rebalance adapter
        uint120 auctionDuration;
        /// @notice The initial price multiplier for the rebalance adapter
        uint256 initialPriceMultiplier;
        /// @notice The minimum price multiplier for the rebalance adapter
        uint256 minPriceMultiplier;
        /// @notice The collateral ratio threshold for the pre-liquidation rebalance adapter
        uint256 preLiquidationCollateralRatioThreshold;
        /// @notice The rebalance reward for the rebalance adapter
        uint256 rebalanceReward;
    }

    /// @notice The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager);

    /// @notice The MorphoLendingAdapterFactory contract
    function morphoLendingAdapterFactory() external view returns (IMorphoLendingAdapterFactory);

    /// @notice Deploys a LeverageToken and deposits collateral into it. The sender receives the shares and debt from the deposit.
    /// @param leverageTokenDeploymentParams The parameters for the leverage token deployment
    /// @param lendingAdapterDeploymentParams The parameters for the lending adapter deployment, used to deploy the leverage token
    /// @param rebalanceAdapterDeploymentParams The parameters for the rebalance adapter deployment, used to deploy the leverage token
    /// @param collateral The collateral to deposit into the leverage token
    /// @param minShares The minimum number of shares to receive from the deposit
    /// @return The leverage token, lending adapter, rebalance adapter, and the action data for the deposit
    /// @dev The lending adapter deployed is a `MorphoLendingAdapter`. The `morphoLendingAdapterFactory` is used to deploy it
    /// as a ERC-1167 minimal proxy.
    /// @dev The rebalance adapter is deployed from the `rebalanceAdapterDeploymentParams.implementation` address as a
    /// UUPS proxy. See the implementation of `deployLeverageTokenAndDeposit` for more details on the parameters passed to the
    /// initializer.
    function deployLeverageTokenAndDeposit(
        LeverageTokenDeploymentParams memory leverageTokenDeploymentParams,
        MorphoLendingAdapterDeploymentParams memory lendingAdapterDeploymentParams,
        RebalanceAdapterDeploymentParams memory rebalanceAdapterDeploymentParams,
        uint256 collateral,
        uint256 minShares
    ) external returns (ILeverageToken, ActionData memory);
}
