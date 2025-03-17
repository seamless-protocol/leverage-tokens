# BeaconProxyFactory
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/BeaconProxyFactory.sol)

**Inherits:**
[IBeaconProxyFactory](/src/interfaces/IBeaconProxyFactory.sol/interface.IBeaconProxyFactory.md)


## State Variables
### beacon
The beacon contract


```solidity
address public immutable beacon;
```


### proxies
Returns the address of a beacon proxy by index in the stored list of beacon proxies deployed by the factory


```solidity
address[] public proxies;
```


## Functions
### constructor

Creates a new beacon proxy factory using an upgradeable beacon


```solidity
constructor(address implementation, address beaconOwner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The implementation contract|
|`beaconOwner`|`address`|The owner of the upgradeable beacon|


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
function getProxies() external view returns (address[] memory _proxies);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_proxies`|`address[]`|proxies The list of beacon proxies|


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


### _getDeploySalt

*Returns the deploy salt for the BeaconProxy, which is the hash of the sender and the base salt*


```solidity
function _getDeploySalt(address sender, bytes32 baseSalt) internal pure returns (bytes32 salt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that will deploy the beacon proxy using the factory|
|`baseSalt`|`bytes32`|The base salt used for deterministic deployment|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|The deploy salt for the BeaconProxy|


### _getCreationCode

*Returns the creation code for the BeaconProxy*


```solidity
function _getCreationCode(bytes memory data) internal view returns (bytes memory bytecode);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The initialization data for the BeaconProxy|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bytecode`|`bytes`|The creation code for the BeaconProxy|


