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
    function computeProxyAddress(address sender, bytes memory data, bytes32 baseSalt)
        external
        view
        returns (address proxy)
    {
        return
            Create2.computeAddress(_getDeploySalt(sender, baseSalt), keccak256(_getCreationCode(data)), address(this));
    }

    /// @inheritdoc IBeaconProxyFactory
    function getProxies() external view returns (address[] memory _proxies) {
        return proxies;
    }

    /// @inheritdoc IBeaconProxyFactory
    function createProxy(bytes memory data, bytes32 baseSalt) external returns (address proxy) {
        proxy = Create2.deploy(0, _getDeploySalt(msg.sender, baseSalt), _getCreationCode(data));

        proxies.push(proxy);

        // Emit an event for the newly created proxy
        emit BeaconProxyCreated(proxy, data, baseSalt);
    }

    /// @dev Returns the deploy salt for the BeaconProxy, which is the hash of the sender and the base salt
    /// @param sender The address that will deploy the beacon proxy using the factory
    /// @param baseSalt The base salt used for deterministic deployment
    /// @return salt The deploy salt for the BeaconProxy
    function _getDeploySalt(address sender, bytes32 baseSalt) internal pure returns (bytes32 salt) {
        return keccak256(abi.encode(sender, baseSalt));
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
