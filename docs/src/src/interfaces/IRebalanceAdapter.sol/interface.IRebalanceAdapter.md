# IRebalanceAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/002c85336929e7b2f8b2193e3cb727fe9cf4b9e6/src/interfaces/IRebalanceAdapter.sol)

**Inherits:**
[IRebalanceAdapterBase](/src/interfaces/IRebalanceAdapterBase.sol/interface.IRebalanceAdapterBase.md)


## Functions
### getAuthorizedCreator

Returns the authorized creator of the RebalanceAdapter


```solidity
function getAuthorizedCreator() external view returns (address authorizedCreator);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`authorizedCreator`|`address`|The authorized creator of the RebalanceAdapter|


### getLeverageManager

Returns the LeverageManager of the RebalanceAdapter


```solidity
function getLeverageManager() external view returns (ILeverageManager leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`leverageManager`|`ILeverageManager`|The LeverageManager of the RebalanceAdapter|


## Events
### RebalanceAdapterInitialized
Event emitted when the rebalance adapter is initialized


```solidity
event RebalanceAdapterInitialized(address indexed authorizedCreator, ILeverageManager indexed leverageManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`authorizedCreator`|`address`|The authorized creator of the RebalanceAdapter, allowed to create LeverageTokens using this adapter|
|`leverageManager`|`ILeverageManager`|The LeverageManager of the RebalanceAdapter|

## Errors
### Unauthorized
Error thrown when the caller is not the authorized creator of the RebalanceAdapter


```solidity
error Unauthorized();
```

