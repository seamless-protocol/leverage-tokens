// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Internal imports

import {StrategyTokenBaseTest} from "./StrategyTokenBase.t.sol";
import {StrategyToken} from "src/StrategyToken.sol";

contract BurnTest is StrategyTokenBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function test_burn(address from, uint256 amount, uint256 prevBalance) public {
        vm.assume(from != address(0));
        vm.assume(prevBalance >= amount);

        strategyToken.mint(from, prevBalance);
        strategyToken.burn(from, amount);

        assertEq(strategyToken.balanceOf(from), prevBalance - amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function test_burn_RevertIf_CallerIsNotOwner(address caller, address from, uint256 amount) public {
        vm.assume(caller != address(0));

        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        strategyToken.burn(from, amount);
        vm.stopPrank();
    }
}
