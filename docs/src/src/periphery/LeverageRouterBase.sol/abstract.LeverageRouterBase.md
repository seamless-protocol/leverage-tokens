# LeverageRouterBase
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6c745a1fb2c5cc77df7fd3106f57db1adc947b75/src/periphery/LeverageRouterBase.sol)

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

