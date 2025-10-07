// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Internal imports
import {ActionData, ExternalAction} from "src/types/DataTypes.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IRebalanceAdapter} from "src/interfaces/IRebalanceAdapter.sol";
import {ILeverageTokenDeploymentBatcher} from "src/interfaces/periphery/ILeverageTokenDeploymentBatcher.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {RebalanceAdapter} from "src/rebalance/RebalanceAdapter.sol";
import {LeverageTokenDeploymentBatcherTest} from "./LeverageTokenDeploymentBatcher.t.sol";

contract DeployLeverageTokenAndDepositTest is LeverageTokenDeploymentBatcherTest {
    function testFork_deployLeverageTokenAndDeposit() public {
        ILeverageTokenDeploymentBatcher.LeverageTokenDeploymentParams memory leverageTokenDeploymentParams =
        ILeverageTokenDeploymentBatcher.LeverageTokenDeploymentParams({
            leverageTokenName: "Leverage Token Name",
            leverageTokenSymbol: "Leverage Token Symbol",
            mintTokenFee: 10,
            redeemTokenFee: 20
        });

        ILeverageTokenDeploymentBatcher.MorphoLendingAdapterDeploymentParams memory lendingAdapterDeploymentParams =
        ILeverageTokenDeploymentBatcher.MorphoLendingAdapterDeploymentParams({
            morphoMarketId: CBBTC_USDC_MARKET_ID,
            baseSalt: bytes32(vm.randomUint())
        });

        address owner = address(0xBEEF);
        ILeverageTokenDeploymentBatcher.RebalanceAdapterDeploymentParams memory rebalanceAdapterDeploymentParams =
        ILeverageTokenDeploymentBatcher.RebalanceAdapterDeploymentParams({
            implementation: address(rebalanceAdapterImplementation),
            owner: owner,
            minCollateralRatio: 1.5e18,
            targetCollateralRatio: 2e18,
            maxCollateralRatio: 2.5e18,
            auctionDuration: 7 minutes,
            initialPriceMultiplier: 1.2 * 1e18,
            minPriceMultiplier: 0.9 * 1e18,
            preLiquidationCollateralRatioThreshold: 1.1e18,
            rebalanceReward: 40_000
        });

        deal(address(CBBTC), user, 0.1e8);

        vm.startPrank(user);
        CBBTC.approve(address(leverageTokenDeploymentBatcher), 0.1e8);
        (ILeverageToken _leverageToken, ActionData memory depositData) = leverageTokenDeploymentBatcher
            .deployLeverageTokenAndDeposit(
            leverageTokenDeploymentParams,
            lendingAdapterDeploymentParams,
            rebalanceAdapterDeploymentParams,
            0.1e8,
            0.1e8
        );
        vm.stopPrank();

        // Receives shares and debt
        assertEq(_leverageToken.balanceOf(user), depositData.shares);
        assertEq(USDC.balanceOf(user), depositData.debt);

        // Sanity check: LendingAdapter
        IMorphoLendingAdapter _lendingAdapter =
            IMorphoLendingAdapter(address(leverageManager.getLeverageTokenLendingAdapter(_leverageToken)));
        assertEq(address(_lendingAdapter.leverageManager()), address(leverageManager));
        assertEq(
            abi.encode(_lendingAdapter.morphoMarketId()), abi.encode(lendingAdapterDeploymentParams.morphoMarketId)
        );
        assertEq(_lendingAdapter.isUsed(), true);

        // Sanity check: RebalanceAdapter
        IRebalanceAdapter _rebalanceAdapter =
            IRebalanceAdapter(address(leverageManager.getLeverageTokenRebalanceAdapter(_leverageToken)));
        assertEq(_rebalanceAdapter.getLeverageTokenInitialCollateralRatio(_leverageToken), 2e18);
        assertEq(RebalanceAdapter(address(_rebalanceAdapter)).owner(), owner);

        // Sanity check: LeverageToken
        assertEq(
            leverageManager.getLeverageTokenActionFee(_leverageToken, ExternalAction.Mint),
            leverageTokenDeploymentParams.mintTokenFee
        );
        assertEq(
            leverageManager.getLeverageTokenActionFee(_leverageToken, ExternalAction.Redeem),
            leverageTokenDeploymentParams.redeemTokenFee
        );
        assertEq(IERC20Metadata(address(_leverageToken)).name(), leverageTokenDeploymentParams.leverageTokenName);
        assertEq(IERC20Metadata(address(_leverageToken)).symbol(), leverageTokenDeploymentParams.leverageTokenSymbol);
    }
}
