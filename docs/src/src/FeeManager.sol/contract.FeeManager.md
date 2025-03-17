# FeeManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/FeeManager.sol)

**Inherits:**
[IFeeManager](/src/interfaces/IFeeManager.sol/interface.IFeeManager.md), Initializable, AccessControlUpgradeable


## State Variables
### MAX_FEE

```solidity
uint256 public constant MAX_FEE = 100_00;
```


### FEE_MANAGER_ROLE

```solidity
bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
```


## Functions
### _getFeeManagerStorage


```solidity
function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $);
```

### __FeeManager_init


```solidity
function __FeeManager_init(address defaultAdmin) public initializer;
```

### __FeeManager_init_unchained


```solidity
function __FeeManager_init_unchained() internal onlyInitializing;
```

### getStrategyActionFee

Returns fee for specific action on strategy


```solidity
function getStrategyActionFee(IStrategy strategy, ExternalAction action) public view returns (uint256 fee);
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
function getTreasury() public view returns (address treasury);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|Address of the treasury|


### getTreasuryActionFee

Returns treasury fee for specific action


```solidity
function getTreasuryActionFee(ExternalAction action) public view returns (uint256 fee);
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
function setStrategyActionFee(IStrategy strategy, ExternalAction action, uint256 fee)
    external
    onlyRole(FEE_MANAGER_ROLE);
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


```solidity
function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE);
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
function setTreasuryActionFee(ExternalAction action, uint256 fee) external onlyRole(FEE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|Action to set fee for|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


### _computeEquityFees

Computes equity fees based on action

*Fees are always rounded up.*

*If the sum of the strategy fee and the treasury fee is greater than the amount,
the strategy fee is set to the delta of the amount and the treasury fee.*


```solidity
function _computeEquityFees(IStrategy strategy, uint256 equity, ExternalAction action)
    internal
    view
    returns (uint256, uint256, uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to compute fees for|
|`equity`|`uint256`|Amount of equity to compute fees for, denominated in collateral asset|
|`action`|`ExternalAction`|Action to compute fees for, Deposit or Withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|equityToCover Equity to add / remove from the strategy after fees, denominated in collateral asset|
|`<none>`|`uint256`|equityForShares Equity to mint / burn shares for from the strategy after fees, denominated in collateral asset|
|`<none>`|`uint256`|strategyFee Strategy fee amount, denominated in collateral asset|
|`<none>`|`uint256`|treasuryFee Treasury fee amount, denominated in collateral asset|


### _chargeTreasuryFee

Charges a treasury fee if the treasury is set


```solidity
function _chargeTreasuryFee(IERC20 collateralAsset, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralAsset`|`IERC20`|Collateral asset to charge the fee from|
|`amount`|`uint256`|Amount of fee to charge|


## Structs
### FeeManagerStorage
*Struct containing all state for the FeeManager contract*

**Note:**
storage-location: erc7201:seamless.contracts.storage.FeeManager


```solidity
struct FeeManagerStorage {
    address treasury;
    mapping(ExternalAction action => uint256) treasuryActionFee;
    mapping(IStrategy strategy => mapping(ExternalAction action => uint256)) strategyActionFee;
}
```

