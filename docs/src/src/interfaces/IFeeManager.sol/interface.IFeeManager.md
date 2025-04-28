# IFeeManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/ca7af3bd8afb6a515c334e2f448f621a379dc94e/src/interfaces/IFeeManager.sol)


## Functions
### chargeManagementFee

Function that charges any accrued management fees for the LeverageToken by minting shares to the treasury

*If the treasury is not set, the management fee is not charged (shares are not minted to the treasury) but
still accrues*


```solidity
function chargeManagementFee(ILeverageToken token) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to charge management fee for|


### getLastManagementFeeAccrualTimestamp

Returns the timestamp of the most recent management fee accrual for a LeverageToken


```solidity
function getLastManagementFeeAccrualTimestamp(ILeverageToken leverageToken) external view returns (uint120 timestamp);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken to get the timestamp for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint120`|The timestamp of the most recent management fee accrual|


### getLeverageTokenActionFee

Returns the LeverageToken fee for a specific action


```solidity
function getLeverageTokenActionFee(ILeverageToken leverageToken, ExternalAction action)
    external
    view
    returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken to get fee for|
|`action`|`ExternalAction`|The action to get fee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


### getManagementFee

Returns the management fee for the LeverageManager


```solidity
function getManagementFee() external view returns (uint256 fee);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Management fee for the LeverageManager, 100_00 is 100%|


### getTreasury

Returns the address of the treasury


```solidity
function getTreasury() external view returns (address treasury);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The address of the treasury|


### getTreasuryActionFee

Returns the treasury fee for a specific action


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


### setManagementFee

Sets the management fee

*Only `FEE_MANAGER_ROLE` can call this function*


```solidity
function setManagementFee(uint128 fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint128`|Management fee, 100_00 is 100%|


### setTreasury

Sets the address of the treasury. The treasury receives all treasury fees from the LeverageManager. If the
treasury is set to the zero address, the treasury fees are reset to 0 as well

*Only `FEE_MANAGER_ROLE` can call this function*


```solidity
function setTreasury(address treasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The address of the treasury|


### setTreasuryActionFee

Sets the treasury fee for a specific action

*Only `FEE_MANAGER_ROLE` can call this function.*


```solidity
function setTreasuryActionFee(ExternalAction action, uint256 fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|The action to set fee for|
|`fee`|`uint256`|The fee for action, 100_00 is 100%|


## Events
### LeverageTokenActionFeeSet
Emitted when a LeverageToken fee is set for a specific action


```solidity
event LeverageTokenActionFeeSet(ILeverageToken indexed leverageToken, ExternalAction indexed action, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken that the fee was set for|
|`action`|`ExternalAction`|The action that the fee was set for|
|`fee`|`uint256`|The fee that was set|

### ManagementFeeCharged
Emitted when the management fee is charged for a LeverageToken


```solidity
event ManagementFeeCharged(ILeverageToken indexed leverageToken, uint256 sharesFee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken that the management fee was charged for|
|`sharesFee`|`uint256`|The amount of shares that were minted to the treasury|

### ManagementFeeSet
Emitted when the management fee is set


```solidity
event ManagementFeeSet(uint128 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint128`|The fee that was set|

### TreasuryActionFeeSet
Emitted when a treasury fee is set for a specific action


```solidity
event TreasuryActionFeeSet(ExternalAction indexed action, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|The action that the fee was set for|
|`fee`|`uint256`|The fee that was set|

### TreasurySet
Emitted when the treasury address is set


```solidity
event TreasurySet(address treasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The address of the treasury|

## Errors
### FeeTooHigh
Error emitted when `FEE_MANAGER_ROLE` tries to set fee higher than `MAX_FEE`


```solidity
error FeeTooHigh(uint256 fee, uint256 maxFee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|The fee that was set|
|`maxFee`|`uint256`|The maximum fee that can be set|

### TreasuryNotSet
Error emitted when trying to set a treasury fee when the treasury address is not set


```solidity
error TreasuryNotSet();
```

