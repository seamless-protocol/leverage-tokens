# FeeManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e2065c10183acb51865104847d299ff5ad4684d2/src/FeeManager.sol)

**Inherits:**
[IFeeManager](/src/interfaces/IFeeManager.sol/interface.IFeeManager.md), Initializable, AccessControlUpgradeable

*The FeeManager contract is an upgradeable core contract that is responsible for managing the fees for LeverageTokens.
There are two types of fees, both of which can be configured to be applied on deposits and withdrawals:
- LeverageToken fees: Fees charged that accumulate towards the value of the LeverageToken for current LeverageToken holders
- Treasury fees: Fees charged that are transferred to the configured treasury address
The maximum fee that can be set for each action is 100_00 (100%). If the LeverageToken fee + the treasury fee is greater than
the maximum fee, the LeverageToken fee is set to the delta of the maximum fee and the treasury fee.*


## State Variables
### MAX_FEE
Returns the max fee that can be set


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

### getLeverageTokenActionFee

Returns the LeverageToken fee for a specific action


```solidity
function getLeverageTokenActionFee(ILeverageToken token, ExternalAction action) public view returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`||
|`action`|`ExternalAction`|The action to get fee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


### getTreasury

Returns the address of the treasury


```solidity
function getTreasury() public view returns (address treasury);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The address of the treasury|


### getTreasuryActionFee

Returns the treasury fee for a specific action


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


### setTreasury

Sets the address of the treasury. The treasury receives all treasury fees from the LeverageManager. If the
treasury is set to the zero address, the treasury fees are reset to 0 as well

*Only `FEE_MANAGER_ROLE` can call this function*


```solidity
function setTreasury(address treasury) external onlyRole(FEE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The address of the treasury|


### setTreasuryActionFee

Sets the treasury fee for a specific action

*Only `FEE_MANAGER_ROLE` can call this function.*


```solidity
function setTreasuryActionFee(ExternalAction action, uint256 fee) external onlyRole(FEE_MANAGER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`ExternalAction`|The action to set fee for|
|`fee`|`uint256`|The fee for action, 100_00 is 100%|


### _computeEquityFees

Computes equity fees based on action

*Fees are always rounded up.*

*If the sum of the LeverageToken fee and the treasury fee is greater than the amount,
the LeverageToken fee is set to the delta of the amount and the treasury fee.*


```solidity
function _computeEquityFees(ILeverageToken token, uint256 equity, ExternalAction action)
    internal
    view
    returns (uint256, uint256, uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to compute fees for|
|`equity`|`uint256`|Amount of equity to compute fees for, denominated in collateral asset|
|`action`|`ExternalAction`|Action to compute fees for, Deposit or Withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|equityToCover Equity to add / remove from the LeverageToken after fees, denominated in the collateral asset of the LeverageToken|
|`<none>`|`uint256`|equityForShares Equity to mint / burn shares for the LeverageToken after fees, denominated in the collateral asset of the LeverageToken|
|`<none>`|`uint256`|tokenFee LeverageToken fee amount, denominated in the collateral asset of the LeverageToken|
|`<none>`|`uint256`|treasuryFee Treasury fee amount, denominated in the collateral asset of the LeverageToken|


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


### _setLeverageTokenActionFee

Sets the LeverageToken fee for a specific action

*If caller tries to set fee above 100% it reverts with FeeTooHigh error*


```solidity
function _setLeverageTokenActionFee(ILeverageToken token, ExternalAction action, uint256 fee) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to set fee for|
|`action`|`ExternalAction`|Action to set fee for|
|`fee`|`uint256`|Fee for action, 100_00 is 100%|


## Structs
### FeeManagerStorage
*Struct containing all state for the FeeManager contract*

**Note:**
storage-location: erc7201:seamless.contracts.storage.FeeManager


```solidity
struct FeeManagerStorage {
    address treasury;
    mapping(ExternalAction action => uint256) treasuryActionFee;
    mapping(ILeverageToken token => mapping(ExternalAction action => uint256)) tokenActionFee;
}
```

