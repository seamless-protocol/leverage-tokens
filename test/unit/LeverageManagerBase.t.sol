// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LeverageManagerBaseTest is Test {
    address public defaultAdmin = makeAddr("defaultAdmin");
    address public manager = makeAddr("manager");

    LeverageManager public leverageManager;

    function setUp() public virtual {
        address leverageManagerImplementation = address(new LeverageManager());
        address leverageManagerProxy = address(
            new ERC1967Proxy(
                leverageManagerImplementation, abi.encodeWithSelector(LeverageManager.initialize.selector, defaultAdmin)
            )
        );

        leverageManager = LeverageManager(leverageManagerProxy);

        vm.startPrank(defaultAdmin);
        leverageManager.grantRole(leverageManager.MANAGER_ROLE(), manager);
        vm.stopPrank();
    }

    function test_setUp() public view {
        assertTrue(leverageManager.hasRole(leverageManager.DEFAULT_ADMIN_ROLE(), defaultAdmin));
    }
}
