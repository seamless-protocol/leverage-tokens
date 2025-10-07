// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LeverageManager} from "src/LeverageManager.sol";

contract DeployLeverageManagerImplementation is Script {
    function run() public {
        address deployerAddress = msg.sender;

        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("DeployerAddress: ", deployerAddress);

        console.log("Deploying...");

        vm.startBroadcast();

        LeverageManager leverageManagerImplementation = new LeverageManager();
        console.log("LeverageManager implementation deployed at: ", address(leverageManagerImplementation));

        vm.stopBroadcast();
    }
}
