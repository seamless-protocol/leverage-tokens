// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IBeaconProxyFactory {
    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Emitted when a new beacon proxy is created
    /// @param proxy The address of the new beacon proxy
    /// @param data The data used to initialize the beacon proxy
    event BeaconProxyCreated(address indexed proxy, bytes data);

    /// @notice The beacon contract
    function beacon() external view returns (address);

    /// @notice Creates a new beacon proxy
    /// @param data The data to initialize the beacon proxy with
    /// @return proxy The address of the new beacon proxy
    function createProxy(bytes memory data) external returns (address proxy);

    /// @notice The list of beacon proxies deployed by the factory
    /// @return proxies The list of beacon proxies
    function getProxies() external view returns (address[] memory proxies);

    /// @notice The list of beacon proxies
    /// @param index The index of the beacon proxy in the storage list of beacon proxies
    /// @return proxy The address of the beacon proxy
    function proxies(uint256 index) external view returns (address proxy);
}
