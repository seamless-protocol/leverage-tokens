// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LeverageTokenLens} from "src/periphery/LeverageTokenLens.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract DeployLeverageTokenLens is Script {
    function run() public {
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast();

        address deployerAddress = msg.sender;
        console.log("DeployerAddress: ", deployerAddress);

        LeverageTokenLens leverageTokenLens = new LeverageTokenLens(ILeverageManager(DeployConstants.LEVERAGE_MANAGER));
        console.log("LeverageTokenLens deployed at: ", address(leverageTokenLens));

        vm.stopBroadcast();
    }
}
