# LeverageRouterBase
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/c66c8e188b984325bffdd199b88ca303e9f58b11/src/periphery/LeverageRouterBase.sol)

**Inherits:**
[ILeverageRouterBase](/src/interfaces/periphery/ILeverageRouterBase.sol/interface.ILeverageRouterBase.md)


## State Variables
### leverageManager

```solidity
ILeverageManager public immutable leverageManager;
```


### morpho

```solidity
IMorpho public immutable morpho;
```


## Functions
### constructor

Creates a new LeverageRouterBase


```solidity
constructor(ILeverageManager _leverageManager, IMorpho _morpho);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


### receive


```solidity
receive() external payable;
```

