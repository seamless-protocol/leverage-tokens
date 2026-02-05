// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Forge imports
import {Script, console} from "forge-std/Script.sol";

/// Internal imports
import {LeverageTokenDeploymentBatcherV2} from "src/periphery/LeverageTokenDeploymentBatcherV2.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {IAaveLendingAdapterFactory} from "src/interfaces/IAaveLendingAdapterFactory.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract DeployLeverageTokenDeploymentBatcher is Script {
    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast();

        address deployerAddress = msg.sender;
        console.log("DeployerAddress: ", deployerAddress);

        LeverageTokenDeploymentBatcherV2 leverageTokenDeploymentBatcherV2 = new LeverageTokenDeploymentBatcherV2(
            ILeverageManager(DeployConstants.LEVERAGE_MANAGER),
            IMorphoLendingAdapterFactory(DeployConstants.MORPHO_LENDING_ADAPTER_FACTORY),
            IAaveLendingAdapterFactory(DeployConstants.AAVE_LENDING_ADAPTER_FACTORY)
        );
        console.log("LeverageTokenDeploymentBatcherV2 deployed at: ", address(leverageTokenDeploymentBatcherV2));

        vm.stopBroadcast();
    }
}
