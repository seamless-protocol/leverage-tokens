// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// Forge imports
import {Script, console} from "forge-std/Script.sol";

/// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

/// Internal imports
import {MulticallExecutor} from "src/periphery/MulticallExecutor.sol";
import {VeloraAdapter} from "src/periphery/VeloraAdapter.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
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

        LeverageRouter leverageRouter =
            new LeverageRouter(ILeverageManager(DeployConstants.LEVERAGE_MANAGER), IMorpho(DeployConstants.MORPHO));
        console.log("LeverageRouter deployed at: ", address(leverageRouter));

        vm.stopBroadcast();
    }
}
