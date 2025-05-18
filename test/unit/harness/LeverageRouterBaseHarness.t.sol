// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {LeverageRouterBase} from "src/periphery/LeverageRouterBase.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";

contract LeverageRouterBaseHarness is LeverageRouterBase {
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) LeverageRouterBase(_leverageManager, _morpho) {}
}
