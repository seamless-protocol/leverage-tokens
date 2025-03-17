# IRebalanceRewardDistributor
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/IRebalanceRewardDistributor.sol)


## Functions
### computeRebalanceReward

Calculate reward for rebalance caller

*This function is called by the LeverageManager contract to calculate reward for rebalance caller*


```solidity
function computeRebalanceReward(address strategy, StrategyState memory stateBefore, StrategyState memory stateAfter)
    external
    view
    returns (uint256 reward);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`address`|Strategy address|
|`stateBefore`|`StrategyState`|State of the strategy before rebalance|
|`stateAfter`|`StrategyState`|State of the strategy after rebalance|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reward`|`uint256`|Reward for rebalance caller|


