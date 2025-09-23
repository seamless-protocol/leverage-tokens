// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract LeverageRouterHarness is LeverageRouter {
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) LeverageRouter(_leverageManager, _morpho) {}

    function exposed_getReentrancyGuardTransientStorage() external view returns (bool) {
        return _reentrancyGuardEntered();
    }
}
