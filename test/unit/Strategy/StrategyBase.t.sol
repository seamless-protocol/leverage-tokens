// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test, console} from "forge-std/Test.sol";

// Dependency imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UnsafeUpgrades} from "@foundry-upgrades/Upgrades.sol";

// Internal imports
import {Strategy} from "src/Strategy.sol";

contract StrategyBaseTest is Test {
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
        assertEq(strategyToken.owner(), address(this));
    }

    function test_initialize_RevertIf_AlreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        strategyToken.initialize(address(this), "Test name", "Test symbol");
    }
}
