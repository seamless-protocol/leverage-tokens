// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Internal imports
import {IBeaconProxyFactory} from "src/interfaces/IBeaconProxyFactory.sol";

contract BeaconProxyFactory is IBeaconProxyFactory {
    /// @inheritdoc IBeaconProxyFactory
    address public immutable beacon;

    /// @inheritdoc IBeaconProxyFactory
    address[] public proxies;

    /// @notice Creates a new beacon proxy factory using an upgradeable beacon
    /// @param implementation The implementation contract
    /// @param beaconOwner The owner of the upgradeable beacon
    constructor(address implementation, address beaconOwner) {
        if (implementation == address(0) || beaconOwner == address(0)) revert InvalidAddress();
        beacon = address(new UpgradeableBeacon(implementation, beaconOwner));
    }

    /// @inheritdoc IBeaconProxyFactory
    function computeProxyAddress(bytes memory data, bytes32 salt) external view returns (address proxy) {
        return Create2.computeAddress(salt, keccak256(_getCreationCode(data)), address(this));
    }

    /// @inheritdoc IBeaconProxyFactory
    function getProxies() external view returns (address[] memory _proxies) {
        return proxies;
    }

    /// @inheritdoc IBeaconProxyFactory
    function createProxy(bytes memory data, bytes32 salt) external returns (address proxy) {
        proxy = Create2.deploy(0, salt, _getCreationCode(data));

        proxies.push(proxy);

        // Emit an event for the newly created proxy
        emit BeaconProxyCreated(proxy, data);
    }

    /// @dev Returns the creation code for the BeaconProxy
    /// @param data The initialization data for the BeaconProxy
    /// @return bytecode The creation code for the BeaconProxy
    function _getCreationCode(bytes memory data) internal view returns (bytes memory bytecode) {
        bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode, // BeaconProxy's runtime bytecode
            abi.encode(beacon, data) // Constructor arguments: beacon address and initialization data
        );
    }
}
