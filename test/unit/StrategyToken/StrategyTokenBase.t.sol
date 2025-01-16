// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {Strategy} from "src/Strategy.sol";

contract StrategyTokenBaseTest is Test {
    Strategy public strategyToken;

    function setUp() public virtual {
        address strategyTokenImplementation = address(new Strategy());
        address strategyTokenProxy = UnsafeUpgrades.deployUUPSProxy(
            strategyTokenImplementation,
            abi.encodeWithSelector(Strategy.initialize.selector, address(this), "Test name", "Test symbol")
        );

        strategyToken = Strategy(strategyTokenProxy);
    }

    function test_setUp() public view {
        assertEq(strategyToken.name(), "Test name");
        assertEq(strategyToken.symbol(), "Test symbol");
    }
}
