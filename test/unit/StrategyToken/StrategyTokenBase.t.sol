// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {StrategyToken} from "src/StrategyToken.sol";

contract StrategyTokenBaseTest is Test {
    StrategyToken public strategyToken;

    function setUp() public virtual {
        address strategyTokenImplementation = address(new StrategyToken());
        address strategyTokenProxy = UnsafeUpgrades.deployUUPSProxy(
            strategyTokenImplementation,
            abi.encodeWithSelector(StrategyToken.initialize.selector, address(this), "Test name", "Test symbol")
        );

        strategyToken = StrategyToken(strategyTokenProxy);
    }

    function test_setUp() public view {
        assertEq(strategyToken.name(), "Test name");
        assertEq(strategyToken.symbol(), "Test symbol");
    }
}
