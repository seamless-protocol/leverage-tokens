// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {Strategy} from "src/Strategy.sol";

contract BeaconUpgradeToTest is Test {
    address public upgrader = makeAddr("upgrader");
    UpgradeableBeacon public beacon;
    BeaconProxyFactory public factory;
    Strategy public strategyToken;

    function setUp() public {
        address strategyTokenImplementation = address(new Strategy());
        factory = new BeaconProxyFactory(strategyTokenImplementation, upgrader);
        beacon = UpgradeableBeacon(factory.beacon());
        strategyToken = Strategy(
            factory.createProxy(
                abi.encodeWithSelector(Strategy.initialize.selector, address(this), "Test name", "Test symbol"),
                bytes32("0")
            )
        );
    }

    function test_upgradeTo() public {
        address user = makeAddr("user");
        strategyToken.mint(user, 100);

        // Deploy new implementation
        NewStrategy newImplementation = new NewStrategy();

        // Expect the Upgraded event to be emitted
        vm.expectEmit(true, true, true, true);
        emit UpgradeableBeacon.Upgraded(address(newImplementation));

        vm.prank(upgrader);
        beacon.upgradeTo(address(newImplementation));
        NewStrategy newProxy = NewStrategy(
            factory.createProxy(
                abi.encodeWithSelector(Strategy.initialize.selector, address(this), "Test name 2", "Test symbol 2"),
                bytes32("1")
            )
        );

        // Existing proxy deployed from the factory should now point to the new implementation but still have the
        // same storage
        assertEq(NewStrategy(address(strategyToken)).testFunction(), true);
        assertEq(strategyToken.balanceOf(user), 100);
        assertEq(strategyToken.name(), "Test name");
        assertEq(strategyToken.symbol(), "Test symbol");

        // New proxies should use the new implementation
        assertEq(newProxy.testFunction(), true);
        assertEq(newProxy.balanceOf(user), 0);
        assertEq(newProxy.name(), "Test name 2");
        assertEq(newProxy.symbol(), "Test symbol 2");
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_upgradeTo_RevertIf_NonUpgraderUpgrades(address nonUpgrader) public {
        vm.assume(nonUpgrader != upgrader);

        Strategy newImplementation = new Strategy();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonUpgrader));
        vm.prank(nonUpgrader);
        beacon.upgradeTo(address(newImplementation));
    }
}

contract NewStrategy is Strategy {
    function testFunction() public pure returns (bool) {
        return true;
    }
}
