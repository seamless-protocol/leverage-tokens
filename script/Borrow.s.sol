// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Id, IMorpho, MarketParams, Market, Position} from "@morpho-blue/interfaces/IMorpho.sol";

import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {LeverageTokenState} from "src/types/DataTypes.sol";
import {ActionData} from "src/types/DataTypes.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract Borrow is Script {
    ILeverageManager public leverageManager = ILeverageManager(DeployConstants.LEVERAGE_MANAGER);
    IMorpho public morpho = IMorpho(DeployConstants.MORPHO);

    function run() public {
        address lendingAdapterAddress =
            address(leverageManager.getLeverageTokenLendingAdapter(ILeverageToken(DeployConstants.LEVERAGE_TOKEN)));

        vm.startBroadcast(lendingAdapterAddress);

        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            IMorphoLendingAdapter(lendingAdapterAddress).marketParams();

        MarketParams memory marketParams =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        // Borrow 1000 USDC by impersonating the lending adapter
        morpho.borrow(marketParams, 1000e6, 0, lendingAdapterAddress, lendingAdapterAddress);

        vm.stopBroadcast();
    }
}
