// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

// Internal imports
import {IBeaconProxyFactory} from "./interfaces/IBeaconProxyFactory.sol";

contract BeaconProxyFactory is IBeaconProxyFactory {
    /// @inheritdoc IBeaconProxyFactory
    address public beacon;

    /// @inheritdoc IBeaconProxyFactory
    address[] public proxies;

    /// @notice Creates a new beacon proxy factory using an upgradeable beacon
    /// @param implementation The implementation contract
    /// @param beaconOwner The owner of the upgradeable beacon
    constructor(address implementation, address beaconOwner) {
        beacon = address(new UpgradeableBeacon(implementation, beaconOwner));
    }

    /// @inheritdoc IBeaconProxyFactory
    function createProxy(bytes memory data) external returns (address proxy) {
        proxy = address(new BeaconProxy(address(beacon), data));
        proxies.push(proxy);
        return proxy;
    }

    /// @inheritdoc IBeaconProxyFactory
    function getProxies() external view returns (address[] memory) {
        return proxies;
    }
}
