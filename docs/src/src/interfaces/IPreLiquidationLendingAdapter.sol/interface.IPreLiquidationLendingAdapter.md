# IPreLiquidationLendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/5f47bb45d300f9abc725e6a08e82ac80219f0e37/src/interfaces/IPreLiquidationLendingAdapter.sol)

**Inherits:**
[ILendingAdapter](/src/interfaces/ILendingAdapter.sol/interface.ILendingAdapter.md)


## Functions
### getLiquidationPenalty

Returns the liquidation penalty of the position held by the lending adapter

*1e18 means that the liquidation penalty is 100%*


```solidity
function getLiquidationPenalty() external view returns (uint256 liquidationPenalty);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`liquidationPenalty`|`uint256`|Liquidation penalty of the position held by the lending adapter, scaled by 1e18|


