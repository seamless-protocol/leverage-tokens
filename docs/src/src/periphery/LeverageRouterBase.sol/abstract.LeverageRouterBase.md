# LeverageRouterBase
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/ca7af3bd8afb6a515c334e2f448f621a379dc94e/src/periphery/LeverageRouterBase.sol)

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

