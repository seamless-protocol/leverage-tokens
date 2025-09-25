# IPreLiquidationLendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/interfaces/IPreLiquidationLendingAdapter.sol)

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


