// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// Internal imports
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageTokenDeploymentBatcherCow} from "../interfaces/periphery/ILeverageTokenDeploymentBatcherCow.sol";
import {IMorphoLendingAdapter} from "../interfaces/IMorphoLendingAdapter.sol";
import {IMorphoLendingAdapterFactory} from "../interfaces/IMorphoLendingAdapterFactory.sol";
import {IRebalanceAdapter} from "../interfaces/IRebalanceAdapter.sol";
import {RebalanceAdapterCow} from "../rebalance/RebalanceAdapterCow.sol";
import {ActionData, LeverageTokenConfig} from "../types/DataTypes.sol";

/**
 * @dev The LeverageTokenDeploymentBatcher is a periphery contract that can be used to batch deployment of a LeverageToken
 * with a deposit of collateral into the LeverageToken. This is highly recommended to avoid inflation attacks from front-running
 * the initial deposit into the LeverageToken.
 *
 * @custom:contact security@seamlessprotocol.com
 */
contract LeverageTokenDeploymentBatcherCow is ILeverageTokenDeploymentBatcherCow {
    /// @inheritdoc ILeverageTokenDeploymentBatcherCow
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc ILeverageTokenDeploymentBatcherCow
    IMorphoLendingAdapterFactory public immutable morphoLendingAdapterFactory;

    /// @notice Constructor
    /// @param _leverageManager The LeverageManager contract
    constructor(ILeverageManager _leverageManager, IMorphoLendingAdapterFactory _morphoLendingAdapterFactory) {
        leverageManager = _leverageManager;
        morphoLendingAdapterFactory = _morphoLendingAdapterFactory;
    }

    /// @inheritdoc ILeverageTokenDeploymentBatcherCow
    function deployLeverageTokenAndDeposit(
        LeverageTokenDeploymentParams memory leverageTokenDeploymentParams,
        MorphoLendingAdapterDeploymentParams memory lendingAdapterDeploymentParams,
        RebalanceAdapterDeploymentParams memory rebalanceAdapterDeploymentParams,
        uint256 collateral,
        uint256 minShares
    ) public returns (ILeverageToken, ActionData memory) {
        IMorphoLendingAdapter lendingAdapter = morphoLendingAdapterFactory.deployAdapter(
            lendingAdapterDeploymentParams.morphoMarketId,
            address(this),
            salt(msg.sender, lendingAdapterDeploymentParams.baseSalt)
        );

        RebalanceAdapterCow.RebalanceAdapterInitParams memory rebalanceAdapterInitParams =
            RebalanceAdapterCow.RebalanceAdapterInitParams({
                owner: rebalanceAdapterDeploymentParams.owner,
                authorizedCreator: address(this),
                leverageManager: leverageManager,
                minCollateralRatio: rebalanceAdapterDeploymentParams.minCollateralRatio,
                targetCollateralRatio: rebalanceAdapterDeploymentParams.targetCollateralRatio,
                maxCollateralRatio: rebalanceAdapterDeploymentParams.maxCollateralRatio,
                auctionDuration: rebalanceAdapterDeploymentParams.auctionDuration,
                initialPriceMultiplier: rebalanceAdapterDeploymentParams.initialPriceMultiplier,
                minPriceMultiplier: rebalanceAdapterDeploymentParams.minPriceMultiplier,
                preLiquidationCollateralRatioThreshold: rebalanceAdapterDeploymentParams.preLiquidationCollateralRatioThreshold,
                rebalanceReward: rebalanceAdapterDeploymentParams.rebalanceReward,
                cowTrampoline: rebalanceAdapterDeploymentParams.cowTrampoline
            });

        IRebalanceAdapter rebalanceAdapter = IRebalanceAdapter(
            UnsafeUpgrades.deployUUPSProxy(
                rebalanceAdapterDeploymentParams.implementation,
                abi.encodeCall(RebalanceAdapterCow.initialize, (rebalanceAdapterInitParams))
            )
        );

        LeverageTokenConfig memory leverageTokenConfig = LeverageTokenConfig({
            lendingAdapter: lendingAdapter,
            rebalanceAdapter: IRebalanceAdapter(rebalanceAdapter),
            mintTokenFee: leverageTokenDeploymentParams.mintTokenFee,
            redeemTokenFee: leverageTokenDeploymentParams.redeemTokenFee
        });

        ILeverageToken leverageToken = leverageManager.createNewLeverageToken(
            leverageTokenConfig,
            leverageTokenDeploymentParams.leverageTokenName,
            leverageTokenDeploymentParams.leverageTokenSymbol
        );

        IERC20 collateralAsset = leverageTokenConfig.lendingAdapter.getCollateralAsset();
        SafeERC20.safeTransferFrom(collateralAsset, msg.sender, address(this), collateral);

        SafeERC20.forceApprove(collateralAsset, address(leverageManager), collateral);
        ActionData memory depositData = leverageManager.deposit(leverageToken, collateral, minShares);

        // Transfer shares and debt received from the deposit to the sender
        SafeERC20.safeTransfer(leverageToken, msg.sender, depositData.shares);
        SafeERC20.safeTransfer(leverageTokenConfig.lendingAdapter.getDebtAsset(), msg.sender, depositData.debt);

        return (leverageToken, depositData);
    }

    /// @notice Given the `sender` and `baseSalt`, return the salt that will be used for deployment.
    /// @param sender The address of the sender.
    /// @param baseSalt The user-provided base salt.
    function salt(address sender, bytes32 baseSalt) internal pure returns (bytes32) {
        return keccak256(abi.encode(sender, baseSalt));
    }
}
