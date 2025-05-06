// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SwapAdapter} from "src/periphery/SwapAdapter.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterFactory} from "src/lending/MorphoLendingAdapterFactory.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract PeripheryDeploy is Script {
    // TODO: Update this to the actual address
    address public LEVERAGE_MANAGER = 0x0000000000000000000000000000000000000000;
    address public MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);

        console.log("Deploying...");

        vm.startBroadcast(deployerPrivateKey);

        SwapAdapter swapAdapter = new SwapAdapter();
        console.log("SwapAdapter deployed at: ", address(swapAdapter));

        LeverageRouter leverageRouter =
            new LeverageRouter(ILeverageManager(LEVERAGE_MANAGER), IMorpho(MORPHO), ISwapAdapter(swapAdapter));
        console.log("LeverageRouter deployed at: ", address(leverageRouter));

        vm.stopBroadcast();
    }
}
