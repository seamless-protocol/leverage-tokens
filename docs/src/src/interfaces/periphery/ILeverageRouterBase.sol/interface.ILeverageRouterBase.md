# ILeverageRouterBase
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/c66c8e188b984325bffdd199b88ca303e9f58b11/src/interfaces/periphery/ILeverageRouterBase.sol)


## Functions
### leverageManager

The LeverageManager contract


```solidity
function leverageManager() external view returns (ILeverageManager _leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|


### morpho

The Morpho core protocol contract


```solidity
function morpho() external view returns (IMorpho _morpho);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


## Errors
### Unauthorized
Error thrown when the caller is not authorized to execute a function


```solidity
error Unauthorized();
```

