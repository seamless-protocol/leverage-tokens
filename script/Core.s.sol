// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterFactory} from "src/lending/MorphoLendingAdapterFactory.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract CoreDeploy is Script {
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

        LeverageToken leverageTokenImplementation = new LeverageToken();
        console.log("LeverageToken implementation deployed at: ", address(leverageTokenImplementation));

        BeaconProxyFactory leverageTokenFactory =
            new BeaconProxyFactory(address(leverageTokenImplementation), deployerAddress);
        console.log("LeverageToken factory deployed at: ", address(leverageTokenFactory));

        LeverageManager leverageManagerImplementation = new LeverageManager();
        console.log("LeverageManager implementation deployed at: ", address(leverageManagerImplementation));

        ERC1967Proxy leverageManagerProxy = new ERC1967Proxy(
            address(leverageManagerImplementation),
            abi.encodeWithSelector(LeverageManager.initialize.selector, deployerAddress, leverageTokenFactory)
        );
        console.log("LeverageManager proxy deployed at: ", address(leverageManagerProxy));

        MorphoLendingAdapter lendingAdapter =
            new MorphoLendingAdapter(ILeverageManager(address(leverageManagerProxy)), IMorpho(MORPHO));
        console.log("LendingAdapter deployed at: ", address(lendingAdapter));

        MorphoLendingAdapterFactory lendingAdapterFactory = new MorphoLendingAdapterFactory(lendingAdapter);
        console.log("LendingAdapterFactory deployed at: ", address(lendingAdapterFactory));

        vm.stopBroadcast();
    }
}
