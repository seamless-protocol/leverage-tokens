// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {IFeeManager} from "src/interfaces/IFeeManager.sol";
import {FeeManager} from "src/FeeManager.sol";
import {FeeManagerWrapper} from "test/unit/FeeManager/wrappers/FeeManagerWrapper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FeeManagerBaseTest is Test {
    address public feeManagerRole = makeAddr("feeManagerRole");

    FeeManagerWrapper public feeManager;

    function setUp() public virtual {
        address feeManagerImplementation = address(new FeeManagerWrapper());
        address feeManagerProxy = address(
            new ERC1967Proxy(
                feeManagerImplementation, abi.encodeWithSelector(FeeManager.__FeeManager_init.selector, address(this))
            )
        );

        feeManager = FeeManagerWrapper(feeManagerProxy);
        feeManager.grantRole(feeManager.FEE_MANAGER_ROLE(), feeManagerRole);
    }

    function test_setUp() public view {
        assertTrue(feeManager.hasRole(feeManager.FEE_MANAGER_ROLE(), feeManagerRole));
    }

    function _setStrategyActionFee(address caller, address strategy, IFeeManager.Action action, uint256 fee) internal {
        vm.prank(caller);
        feeManager.setStrategyActionFee(strategy, action, fee);
    }
}
