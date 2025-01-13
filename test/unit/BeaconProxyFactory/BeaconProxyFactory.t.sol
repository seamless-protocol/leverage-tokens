// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {BeaconProxyFactory} from "src/BeaconProxyFactory.sol";
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";

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

    function test_constructor_RevertIf_ImplementationIsZeroAddress() public {
        vm.expectRevert(IBeaconProxyFactory.InvalidAddress.selector);
        new BeaconProxyFactory(address(0), owner);
    }

    function test_constructor_RevertIf_OwnerIsZeroAddress() public {
        vm.expectRevert(IBeaconProxyFactory.InvalidAddress.selector);
        new BeaconProxyFactory(implementation, address(0));
    }

    function testFuzz_createProxy_WithoutInitializationData(bytes32 salt) public {
        bytes memory data = hex"";
        address expectedProxyAddress = factory.computeProxyAddress(data, salt);

        vm.expectEmit(true, true, true, true);
        emit IBeaconProxyFactory.BeaconProxyCreated(expectedProxyAddress, data);
        address proxy = factory.createProxy(data, salt);

        assertEq(proxy, expectedProxyAddress);
        assertEq(factory.getProxies().length, 1);
        assertEq(factory.getProxies()[0], proxy);
        assertEq(MockImplementation(proxy).mockFunction(), 0); // Zero because it was not initialized
    }

    function testFuzz_createProxy_WithInitializationData(bytes32 salt) public {
        uint256 value = 100;
        address expectedProxyAddress =
            factory.computeProxyAddress(abi.encodeWithSelector(MockImplementation.initialize.selector, value), salt);

        vm.expectCall(implementation, abi.encodeWithSelector(MockImplementation.initialize.selector, value));
        vm.expectEmit(true, true, true, true);
        emit IBeaconProxyFactory.BeaconProxyCreated(
            expectedProxyAddress, abi.encodeWithSelector(MockImplementation.initialize.selector, value)
        );
        address proxy = factory.createProxy(abi.encodeWithSelector(MockImplementation.initialize.selector, value), salt);

        assertEq(MockImplementation(proxy).mockFunction(), value);
        assertEq(factory.getProxies().length, 1);
        assertEq(factory.getProxies()[0], proxy);
        assertEq(proxy, expectedProxyAddress);
    }
}
