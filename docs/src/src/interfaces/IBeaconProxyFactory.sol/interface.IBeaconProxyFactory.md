# IBeaconProxyFactory
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/IBeaconProxyFactory.sol)


## Functions
### beacon

The beacon contract


```solidity
function beacon() external view returns (address beacon);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`beacon`|`address`|The address of the beacon contract|


### computeProxyAddress

Computes the address of a beacon proxy before deployment


```solidity
function computeProxyAddress(address sender, bytes memory data, bytes32 baseSalt)
    external
    view
    returns (address proxy);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that will deploy the beacon proxy using the factory|
|`data`|`bytes`|The initialization data passed to the proxy|
|`baseSalt`|`bytes32`|The base salt used for deterministic deployment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proxy`|`address`|The predicted address of the beacon proxy|


### getProxies

The list of beacon proxies deployed by the factory


```solidity
function getProxies() external view returns (address[] memory proxies);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proxies`|`address[]`|The list of beacon proxies|


### proxies

Returns the address of a beacon proxy by index in the stored list of beacon proxies deployed by the factory


```solidity
function proxies(uint256 index) external view returns (address proxy);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the beacon proxy in the stored list of beacon proxies|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proxy`|`address`|The address of the beacon proxy|


### createProxy

Creates a new beacon proxy


```solidity
function createProxy(bytes memory data, bytes32 baseSalt) external returns (address proxy);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The initialization data passed to the proxy|
|`baseSalt`|`bytes32`|The base salt used for deterministic deployment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proxy`|`address`|The address of the new beacon proxy|


## Events
### BeaconProxyCreated
Emitted when a new beacon proxy is created


```solidity
event BeaconProxyCreated(address indexed proxy, bytes data, bytes32 baseSalt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proxy`|`address`|The address of the new beacon proxy|
|`data`|`bytes`|The data used to initialize the beacon proxy|
|`baseSalt`|`bytes32`|The base salt used for deterministic deployment|

## Errors
### InvalidAddress
Error thrown when an invalid address is provided


```solidity
error InvalidAddress();
```

