# LeverageRouterBase
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/002c85336929e7b2f8b2193e3cb727fe9cf4b9e6/src/periphery/LeverageRouterBase.sol)

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

