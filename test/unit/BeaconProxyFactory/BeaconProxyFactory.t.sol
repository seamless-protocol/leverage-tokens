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
import {MockValue} from "../mock/MockValue.sol";

contract BeaconProxyFactoryTest is Test {
    BeaconProxyFactory public factory;

    address public implementation;
    address public owner = makeAddr("owner");
    UpgradeableBeacon public beacon;

    function setUp() public {
        implementation = address(new MockValue());
        factory = new BeaconProxyFactory(implementation, owner);
        beacon = UpgradeableBeacon(address(factory));
    }

    function test_constructor() public view {
        assertEq(factory.implementation(), implementation);
        assertEq(factory.owner(), owner);
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_createProxy_WithoutInitializationData(bytes32 salt) public {
        bytes memory data = hex"";
        address expectedProxyAddress = factory.computeProxyAddress(address(this), data, salt);

        vm.expectEmit(true, true, true, true);
        emit IBeaconProxyFactory.BeaconProxyCreated(expectedProxyAddress, data, salt);
        address proxy = factory.createProxy(data, salt);

        assertEq(proxy, expectedProxyAddress);
        assertEq(factory.numProxies(), 1);
        assertEq(MockValue(proxy).mockFunction(), 0); // Zero because it was not initialized
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_createProxy_WithInitializationData(bytes32 salt) public {
        uint256 value = 100;
        bytes memory data = abi.encodeWithSelector(MockValue.initialize.selector, value);
        address expectedProxyAddress = factory.computeProxyAddress(address(this), data, salt);

        vm.expectCall(implementation, data);
        vm.expectEmit(true, true, true, true);
        emit IBeaconProxyFactory.BeaconProxyCreated(expectedProxyAddress, data, salt);
        address proxy = factory.createProxy(data, salt);

        assertEq(MockValue(proxy).mockFunction(), value);
        assertEq(MockValue(proxy).initialized(), true);
        assertEq(factory.numProxies(), 1);
        assertEq(proxy, expectedProxyAddress);
    }

    function testFuzz_computeProxyAddress_DifferentSalt(bytes32 saltA, bytes32 saltB) public view {
        vm.assume(saltA != saltB);
        bytes memory emptyData = hex"";
        address expectedProxyAddressA = factory.computeProxyAddress(address(this), emptyData, saltA);
        address expectedProxyAddressB = factory.computeProxyAddress(address(this), emptyData, saltB);

        assertNotEq(expectedProxyAddressA, expectedProxyAddressB);

        bytes memory initializeData = abi.encodeWithSelector(MockValue.initialize.selector, 100);
        address expectedProxyAddressC = factory.computeProxyAddress(address(this), initializeData, saltA);
        address expectedProxyAddressD = factory.computeProxyAddress(address(this), initializeData, saltB);

        assertNotEq(expectedProxyAddressC, expectedProxyAddressD);
    }

    function testFuzz_computeProxyAddress_SameInitializationDataAndSaltDifferentDeployers(
        address deployerA,
        address deployerB
    ) public view {
        vm.assume(deployerA != deployerB);

        bytes memory initializeData = abi.encodeWithSelector(MockValue.initialize.selector, 100);
        bytes32 salt = bytes32(uint256(1));

        address expectedProxyAddressA = factory.computeProxyAddress(deployerA, initializeData, salt);
        address expectedProxyAddressB = factory.computeProxyAddress(deployerB, initializeData, salt);

        assertNotEq(expectedProxyAddressA, expectedProxyAddressB);
    }

    function testFuzz_createProxy_SameInitializationDataAndSaltDifferentDeployers(address deployerA, address deployerB)
        public
        view
    {
        vm.assume(deployerA != deployerB);

        bytes memory initializeData = abi.encodeWithSelector(MockValue.initialize.selector, 100);
        bytes32 salt = bytes32(uint256(1));

        // Expect neither to revert
        factory.computeProxyAddress(deployerA, initializeData, salt);
        factory.computeProxyAddress(deployerB, initializeData, salt);
    }
}
