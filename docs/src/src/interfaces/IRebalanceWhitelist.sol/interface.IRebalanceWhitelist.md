# IRebalanceWhitelist
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/IRebalanceWhitelist.sol)


## Functions
### isAllowedToRebalance

Returns if given user is allowed to rebalance certain strategy

*Leverage manager calls this function in case manager wants to enforce different rebalance mechanisms in external contract*


```solidity
function isAllowedToRebalance(address strategy, address user) external view returns (bool isAllowed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`address`|Strategy to check rebalancer for|
|`user`|`address`|User to check eligibility for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isAllowed`|`bool`|Is allowed to rebalance|


