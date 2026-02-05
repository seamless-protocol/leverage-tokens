// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// Forge imports
import {Script, console} from "forge-std/Script.sol";

/// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IPool} from "@aave-v3-origin/contracts/interfaces/IPool.sol";

/// Internal imports
import {MulticallExecutor} from "src/periphery/MulticallExecutor.sol";
import {VeloraAdapter} from "src/periphery/VeloraAdapter.sol";
import {LeverageRouterV2} from "src/periphery/LeverageRouterV2.sol";
import {LeverageTokenDeploymentBatcherV2} from "src/periphery/LeverageTokenDeploymentBatcherV2.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {IAaveLendingAdapterFactory} from "src/interfaces/IAaveLendingAdapterFactory.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract PeripheryDeploy is Script {
    function run() public {
        address deployerAddress = msg.sender;

        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("DeployerAddress: ", deployerAddress);

        console.log("Deploying...");

        vm.startBroadcast();

        MulticallExecutor multicallExecutor = new MulticallExecutor();
        console.log("MulticallExecutor deployed at: ", address(multicallExecutor));

        VeloraAdapter veloraAdapter = new VeloraAdapter(DeployConstants.AUGUSTUS_REGISTRY);
        console.log("VeloraAdapter deployed at: ", address(veloraAdapter));

        LeverageRouterV2 leverageRouterV2 = new LeverageRouterV2(
            ILeverageManager(DeployConstants.LEVERAGE_MANAGER),
            IMorpho(DeployConstants.MORPHO),
            IPool(DeployConstants.AAVE_POOL)
        );
        console.log("LeverageRouterV2 deployed at: ", address(leverageRouterV2));

        LeverageTokenDeploymentBatcherV2 leverageTokenDeploymentBatcherV2 = new LeverageTokenDeploymentBatcherV2(
            ILeverageManager(DeployConstants.LEVERAGE_MANAGER),
            IMorphoLendingAdapterFactory(DeployConstants.MORPHO_LENDING_ADAPTER_FACTORY),
            IAaveLendingAdapterFactory(DeployConstants.AAVE_LENDING_ADAPTER_FACTORY)
        );
        console.log("LeverageTokenDeploymentBatcherV2 deployed at: ", address(leverageTokenDeploymentBatcherV2));

        vm.stopBroadcast();
    }
}
