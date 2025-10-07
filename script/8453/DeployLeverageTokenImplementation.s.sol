// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LeverageToken} from "src/LeverageToken.sol";

contract DeployLeverageTokenImplementation is Script {
    function run() public {
        address deployerAddress = msg.sender;

        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("DeployerAddress: ", deployerAddress);

        console.log("Deploying...");

        vm.startBroadcast();

        LeverageToken leverageTokenImplementation = new LeverageToken();
        console.log("LeverageToken implementation deployed at: ", address(leverageTokenImplementation));

        vm.stopBroadcast();
    }
}
