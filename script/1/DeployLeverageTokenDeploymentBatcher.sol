// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LeverageTokenDeploymentBatcher} from "src/periphery/LeverageTokenDeploymentBatcher.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapterFactory} from "src/interfaces/IMorphoLendingAdapterFactory.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract DeployLeverageTokenDeploymentBatcher is Script {
    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast();

        address deployerAddress = msg.sender;
        console.log("DeployerAddress: ", deployerAddress);

        LeverageTokenDeploymentBatcher leverageTokenDeploymentBatcher = new LeverageTokenDeploymentBatcher(
            ILeverageManager(DeployConstants.LEVERAGE_MANAGER),
            IMorphoLendingAdapterFactory(DeployConstants.LENDING_ADAPTER_FACTORY)
        );
        console.log("LeverageTokenDeploymentBatcher deployed at: ", address(leverageTokenDeploymentBatcher));

        vm.stopBroadcast();
    }
}
