# IMorphoLendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/IMorphoLendingAdapter.sol)

**Inherits:**
[ILendingAdapter](/src/interfaces/ILendingAdapter.sol/interface.ILendingAdapter.md)


## Functions
### leverageManager

The Seamless ilm-v2 LeverageManager contract


```solidity
function leverageManager() external view returns (ILeverageManager leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`leverageManager`|`ILeverageManager`|The Seamless ilm-v2 LeverageManager contract|


### morphoMarketId

The ID of the Morpho market that the lending adapter manages a position in


```solidity
function morphoMarketId() external view returns (Id morphoMarketId);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`morphoMarketId`|`Id`|The ID of the Morpho market that the lending adapter manages a position in|


### marketParams

The market parameters of the Morpho lending pool


```solidity
function marketParams()
    external
    view
    returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`loanToken`|`address`|The loan token of the Morpho lending pool|
|`collateralToken`|`address`|The collateral token of the Morpho lending pool|
|`oracle`|`address`|The oracle of the Morpho lending pool|
|`irm`|`address`|The IRM of the Morpho lending pool|
|`lltv`|`uint256`|The LLTV of the Morpho lending pool|


### morpho

The Morpho core protocol contract


```solidity
function morpho() external view returns (IMorpho morpho);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`morpho`|`IMorpho`|The Morpho core protocol contract|


