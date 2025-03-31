# IRebalanceAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e2065c10183acb51865104847d299ff5ad4684d2/src/interfaces/IRebalanceAdapter.sol)

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

## Errors
### Unauthorized
Error thrown when the caller is not the authorized creator of the RebalanceAdapter


```solidity
error Unauthorized();
```

