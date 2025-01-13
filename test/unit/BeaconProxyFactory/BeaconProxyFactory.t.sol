// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";

contract MockImplementation {
    uint256 public value;

    function initialize(uint256 _value) public {
        value = _value;
    }

    function mockFunction() public view returns (uint256) {
        return value;
    }
}

contract BeaconProxyFactoryTest is Test {
    BeaconProxyFactory public factory;

    address public implementation;
    address public owner = makeAddr("owner");

    function setUp() public {
        implementation = address(new MockImplementation());
        factory = new BeaconProxyFactory(implementation, owner);
    }

    function test_constructor() public view {
        assertEq(UpgradeableBeacon(factory.beacon()).implementation(), implementation);
        assertEq(UpgradeableBeacon(factory.beacon()).owner(), owner);
    }

    function test_createProxy() public {
        address proxy = factory.createProxy("");
        assertEq(factory.getProxies().length, 1);
        assertEq(factory.getProxies()[0], proxy);

        // Returns zero because the MockImplementation has not been initialized
        assertEq(MockImplementation(proxy).mockFunction(), 0);
    }

    function testFuzz_createProxy_WithEncodedCall(uint256 value) public {
        vm.expectCall(implementation, abi.encodeWithSelector(MockImplementation.initialize.selector, value));
        address proxy = factory.createProxy(abi.encodeWithSelector(MockImplementation.initialize.selector, value));

        assertEq(MockImplementation(proxy).mockFunction(), value);
        assertEq(factory.getProxies().length, 1);
        assertEq(factory.getProxies()[0], proxy);
    }
}
