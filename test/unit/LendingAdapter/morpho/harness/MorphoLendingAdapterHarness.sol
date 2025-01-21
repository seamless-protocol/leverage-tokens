// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

// Internal imports
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {MorphoLendingAdapter} from "src/adapters/MorphoLendingAdapter.sol";

contract MorphoLendingAdapterHarness is MorphoLendingAdapter {
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) MorphoLendingAdapter(_leverageManager, _morpho) {}

    function setCollateralDecimals(uint8 decimals) external {
        collateralDecimals = decimals;
    }

    function setDebtDecimals(uint8 decimals) external {
        debtDecimals = decimals;
    }
}
