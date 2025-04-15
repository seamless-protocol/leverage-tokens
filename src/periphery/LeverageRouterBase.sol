// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "../interfaces/ILeverageManager.sol";
import {ILeverageToken} from "../interfaces/ILeverageToken.sol";
import {ILeverageRouterBase} from "../interfaces/periphery/ILeverageRouterBase.sol";

abstract contract LeverageRouterBase is ILeverageRouterBase {
    ILeverageManager public immutable leverageManager;

    IMorpho public immutable morpho;

    /// @notice Creates a new LeverageRouterBase
    /// @param _leverageManager The LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) {
        leverageManager = _leverageManager;
        morpho = _morpho;
    }

    receive() external payable {}
}
