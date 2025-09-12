// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract LeverageRouterHarness is LeverageRouter {
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) LeverageRouter(_leverageManager, _morpho) {}

    function exposed_getReentrancyGuardTransientStorage() external view returns (bool) {
        // slot used in OZ's ReentrancyGuardTransient
        bytes32 slot = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

        bool value;
        assembly {
            value := tload(slot)
        }

        return value;
    }
}
