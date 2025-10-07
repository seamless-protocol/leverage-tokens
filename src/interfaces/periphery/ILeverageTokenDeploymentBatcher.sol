// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

import {ILeverageManager} from "../ILeverageManager.sol";
import {ILeverageToken} from "../ILeverageToken.sol";
import {IMorphoLendingAdapter} from "../IMorphoLendingAdapter.sol";
import {IMorphoLendingAdapterFactory} from "../IMorphoLendingAdapterFactory.sol";
import {IRebalanceAdapterBase} from "../IRebalanceAdapterBase.sol";
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

    /// @notice The LeverageManager contract
    function leverageManager() external view returns (ILeverageManager);

    /// @notice The MorphoLendingAdapterFactory contract
    function morphoLendingAdapterFactory() external view returns (IMorphoLendingAdapterFactory);

    /// @notice Deploys a LeverageToken and deposits collateral into it
    /// @param leverageTokenDeploymentParams The parameters for the leverage token deployment
    /// @param lendingAdapterDeploymentParams The parameters for the lending adapter deployment, used to deploy the leverage token
    /// @param rebalanceAdapter The rebalance adapter to use
    /// @param collateral The collateral to deposit into the leverage token
    /// @param minShares The minimum number of shares to receive from the deposit
    /// @return The leverage token, lending adapter, and the action data for the deposit
    /// @dev The lending adapter deployed is a `MorphoLendingAdapter`. The `morphoLendingAdapterFactory` is used to deploy it.
    /// @dev The `LeverageTokenDeploymentBatcher` must be allowed to use the `rebalanceAdapter` to create a new leverage token.
    function deployLeverageTokenAndDeposit(
        LeverageTokenDeploymentParams memory leverageTokenDeploymentParams,
        MorphoLendingAdapterDeploymentParams memory lendingAdapterDeploymentParams,
        IRebalanceAdapterBase rebalanceAdapter,
        uint256 collateral,
        uint256 minShares
    ) external returns (ILeverageToken, IMorphoLendingAdapter, ActionData memory);
}
