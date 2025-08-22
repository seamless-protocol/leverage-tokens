// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {ISwapAdapter} from "src/interfaces/periphery/ISwapAdapter.sol";
import {ILeverageRouter} from "src/interfaces/periphery/ILeverageRouter.sol";
import {LeverageRouter} from "src/periphery/LeverageRouter.sol";

contract LeverageRouterHarness is LeverageRouter {
    constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapAdapter _swapper)
        LeverageRouter(_leverageManager, _morpho, _swapper)
    {}

    function exposed_execute(ILeverageRouter.Call calldata call, ILeverageRouter.Approval calldata approval)
        external
        returns (bytes memory result)
    {
        return _execute(call, approval);
    }
}
