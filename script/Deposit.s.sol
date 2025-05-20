// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWETH9} from "src/interfaces/periphery/IWETH9.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {DeployConstants} from "./DeployConstants.sol";

contract Deposit is Script {
    address public WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

    function run() public {
        vm.startBroadcast();

        ILeverageManager leverageManager = ILeverageManager(DeployConstants.LEVERAGE_MANAGER);
        ILeverageToken leverageToken = ILeverageToken(DeployConstants.LEVERAGE_TOKEN);

        // Mint 10 WETH
        IWETH9 weth = IWETH9(WETH_ADDRESS);
        weth.deposit{value: 10e18}();

        // Deposit 1 WETH and the rest stays in wallet
        IERC20(WETH_ADDRESS).approve(address(leverageManager), type(uint256).max);
        leverageManager.mint(leverageToken, 1e18, 0);

        vm.stopBroadcast();
    }
}
