// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageToken} from "src/LeverageToken.sol";
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {MorphoLendingAdapter} from "src/lending/MorphoLendingAdapter.sol";
import {MorphoLendingAdapterFactory} from "src/lending/MorphoLendingAdapterFactory.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {DeployConstants} from "script/DeployConstants.sol";

contract CoreDeploy is Script {
    function run() public {
        address deployerAddress = msg.sender;

        console.log("BlockNumber: ", block.number);
        console.log("ChainId: ", block.chainid);
        console.log("DeployerAddress: ", deployerAddress);

        console.log("Deploying...");

        // Precompute the LeverageManager proxy address
        // The LeverageToken implementation will be deployed first (nonce + 1)
        // The BeaconProxyFactory will be deployed second (nonce + 2)
        // The LeverageManager implementation will be deployed third (nonce + 3)
        // The LeverageManager proxy will be deployed fourth (nonce + 4)
        uint64 currentNonce = vm.getNonce(deployerAddress);
        address precomputedLeverageManagerProxy = vm.computeCreateAddress(deployerAddress, currentNonce + 4);

        vm.startBroadcast();

        LeverageToken leverageTokenImplementation = new LeverageToken(ILeverageManager(precomputedLeverageManagerProxy));
        console.log("LeverageToken implementation deployed at: ", address(leverageTokenImplementation));

        BeaconProxyFactory leverageTokenFactory =
            new BeaconProxyFactory(address(leverageTokenImplementation), DeployConstants.SEAMLESS_TIMELOCK_SHORT);
        console.log("LeverageToken factory deployed at: ", address(leverageTokenFactory));

        address leverageManagerProxy = Upgrades.deployUUPSProxy(
            "LeverageManager.sol",
            abi.encodeCall(
                LeverageManager.initialize,
                (DeployConstants.SEAMLESS_TIMELOCK_SHORT, DeployConstants.SEAMLESS_TREASURY, leverageTokenFactory)
            )
        );
        console.log("LeverageManager proxy deployed at: ", address(leverageManagerProxy));

        // Verify that our precomputed address was correct
        require(leverageManagerProxy == precomputedLeverageManagerProxy, "Precomputed LeverageManager address mismatch");

        MorphoLendingAdapter lendingAdapter =
            new MorphoLendingAdapter(ILeverageManager(address(leverageManagerProxy)), IMorpho(DeployConstants.MORPHO));
        console.log("LendingAdapter deployed at: ", address(lendingAdapter));

        MorphoLendingAdapterFactory lendingAdapterFactory = new MorphoLendingAdapterFactory(lendingAdapter);
        console.log("LendingAdapterFactory deployed at: ", address(lendingAdapterFactory));

        vm.stopBroadcast();
    }
}
