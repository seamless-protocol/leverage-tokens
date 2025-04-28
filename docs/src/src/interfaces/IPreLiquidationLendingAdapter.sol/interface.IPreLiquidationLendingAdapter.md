# IPreLiquidationLendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/ca7af3bd8afb6a515c334e2f448f621a379dc94e/src/interfaces/IPreLiquidationLendingAdapter.sol)

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


