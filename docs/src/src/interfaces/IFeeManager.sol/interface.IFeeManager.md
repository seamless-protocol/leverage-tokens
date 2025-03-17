# IFeeManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/IFeeManager.sol)


## Functions
### getStrategyActionFee

Returns fee for specific action on strategy


```solidity
function getStrategyActionFee(IStrategy strategy, ExternalAction action) external view returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get fee for|
|`action`|`ExternalAction`|Action to get fee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee for action on strategy, 100_00 is 100%|


### getTreasury

Returns address of the treasury


```solidity
function getTreasury() external view returns (address treasury);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|Address of the treasury|


### getTreasuryActionFee

Returns treasury fee for specific action


```solidity
function getTreasuryActionFee(ExternalAction action) external view returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|Action to get fee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


### setStrategyActionFee

Sets fee for specific action on strategy

*Only FEE_MANAGER role can call this function.
If manager tries to set fee above 100% it reverts with FeeTooHigh error*


```solidity
function setStrategyActionFee(IStrategy strategy, ExternalAction action, uint256 fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to set fee for|
|`action`|`ExternalAction`|Action to set fee for|
|`fee`|`uint256`|Fee for action on strategy, 100_00 is 100%|


### setTreasury

Sets address of the treasury. Treasury receives all fees from LeverageManager. If the treasury is set to
the zero address, the treasury fees are reset to 0 as well

*Only FEE_MANAGER role can call this function*

*Emits TreasurySet event*


```solidity
function setTreasury(address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|Address of the treasury|


### setTreasuryActionFee

Sets fee for specific action

*Only FEE_MANAGER role can call this function.
If manager tries to set fee above 100% it reverts with FeeTooHigh error*


```solidity
function setTreasuryActionFee(ExternalAction action, uint256 fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|Action to set fee for|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


## Events
### StrategyActionFeeSet
Emitted when fee is set for strategy for specific action


```solidity
event StrategyActionFeeSet(IStrategy strategy, ExternalAction action, uint256 fee);
```

### TreasuryActionFeeSet
Emitted when treasury fee is set for specific action


```solidity
event TreasuryActionFeeSet(ExternalAction indexed action, uint256 fee);
```

### TreasurySet
Emitted when treasury is set


```solidity
event TreasurySet(address treasury);
```

## Errors
### FeeTooHigh
Error emitted when fee manager tries to set fee higher than MAX_FEE


```solidity
error FeeTooHigh(uint256 fee, uint256 maxFee);
```

### TreasuryNotSet
Error emitted when trying to set treasury fee when treasury address is not set


```solidity
error TreasuryNotSet();
```

