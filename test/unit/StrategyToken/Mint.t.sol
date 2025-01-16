// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Internal imports

import {StrategyTokenBaseTest} from "./StrategyTokenBase.t.sol";
import {Strategy} from "src/Strategy.sol";

contract MintTest is StrategyTokenBaseTest {
    function setUp() public override {
        super.setUp();
    }

    /// forge-config: default.fuzz.runs = 1
    function test_mint(address to, uint256 amount) public {
        vm.assume(to != address(0));

        strategyToken.mint(to, amount);
        assertEq(strategyToken.balanceOf(to), amount);
    }

    /// forge-config: default.fuzz.runs = 1
    function test_mint_RevertIf_CallerIsNotOwner(address caller, address to, uint256 amount) public {
        vm.assume(caller != address(0));

        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        strategyToken.mint(to, amount);
        vm.stopPrank();
    }
}
