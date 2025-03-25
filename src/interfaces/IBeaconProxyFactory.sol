// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IBeaconProxyFactory {
    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Emitted when a new beacon proxy is created
    /// @param proxy The address of the new beacon proxy
    /// @param data The data used to initialize the beacon proxy
    /// @param baseSalt The base salt used for deterministic deployment
    event BeaconProxyCreated(address indexed proxy, bytes data, bytes32 baseSalt);

    /// @notice Computes the address of a beacon proxy before deployment
    /// @param sender The address that will deploy the beacon proxy using the factory
    /// @param data The initialization data passed to the proxy
    /// @param baseSalt The base salt used for deterministic deployment
    /// @return proxy The predicted address of the beacon proxy
    function computeProxyAddress(address sender, bytes memory data, bytes32 baseSalt)
        external
        view
        returns (address proxy);

    /// @notice The list of beacon proxies deployed by the factory
    /// @return proxies The list of beacon proxies
    function getProxies() external view returns (address[] memory proxies);

    /// @notice Returns the address of a beacon proxy by index in the stored list of beacon proxies deployed by the factory
    /// @param index The index of the beacon proxy in the stored list of beacon proxies
    /// @return proxy The address of the beacon proxy
    function proxies(uint256 index) external view returns (address proxy);

    /// @notice Creates a new beacon proxy
    /// @param data The initialization data passed to the proxy
    /// @param baseSalt The base salt used for deterministic deployment
    /// @return proxy The address of the new beacon proxy
    function createProxy(bytes memory data, bytes32 baseSalt) external returns (address proxy);
}
