// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {Strategy} from "src/Strategy.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";

contract IntegrationBase is Test {
    string internal BASE_RPC_URL = vm.envString("BASE_MAINNET_RPC_URL");
    uint256 internal FORK_BLOCK_NUMBER = 25473904;

    IMorpho public immutable MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    ILeverageManager public leverageManager;

    IBeaconProxyFactory public morphoLendingAdapterFactory;
    IMorphoLendingAdapter public morphoLendingAdapterImplementation;

    IBeaconProxyFactory public strategyTokenFactory;
    IStrategy public strategyImplementation;

    function setUp() public virtual {
        vm.createSelectFork(BASE_RPC_URL, FORK_BLOCK_NUMBER);

        // Setup the leverage manager
        leverageManager = new LeverageManager();
        LeverageManager(address(leverageManager)).initialize(address(this));

        // Setup the strategy token factory
        strategyImplementation = new Strategy();
        strategyTokenFactory = new BeaconProxyFactory(address(strategyImplementation), address(this));

        // Setup the morpho lending adapter factory
        morphoLendingAdapterImplementation = new MorphoLendingAdapter(leverageManager, MORPHO);
        morphoLendingAdapterFactory = new BeaconProxyFactory(address(morphoLendingAdapterImplementation), address(this));
    }
}
