# ILeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e940fa5a38a4ecdb2ab814caac34ad52528360be/src/interfaces/ILeverageManager.sol)

**Inherits:**
[IFeeManager](/src/interfaces/IFeeManager.sol/interface.IFeeManager.md)


## Functions
### getLeverageTokenFactory

Returns the factory for creating new LeverageTokens


```solidity
function getLeverageTokenFactory() external view returns (IBeaconProxyFactory factory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`IBeaconProxyFactory`|Factory for creating new LeverageTokens|


### getLeverageTokenLendingAdapter

Returns the lending adapter for a LeverageToken


```solidity
function getLeverageTokenLendingAdapter(ILeverageToken token) external view returns (ILendingAdapter adapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get lending adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`ILendingAdapter`|Lending adapter for the LeverageToken|


### getLeverageTokenCollateralAsset

Returns the collateral asset for a LeverageToken


```solidity
function getLeverageTokenCollateralAsset(ILeverageToken token) external view returns (IERC20 collateralAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get collateral asset for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateralAsset`|`IERC20`|Collateral asset for the LeverageToken|


### getLeverageTokenDebtAsset

Returns the debt asset for a LeverageToken


```solidity
function getLeverageTokenDebtAsset(ILeverageToken token) external view returns (IERC20 debtAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get debt asset for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debtAsset`|`IERC20`|Debt asset for the LeverageToken|


### getLeverageTokenRebalanceAdapter

Returns the rebalance adapter for a LeverageToken


```solidity
function getLeverageTokenRebalanceAdapter(ILeverageToken token) external view returns (IRebalanceAdapterBase adapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get the rebalance adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`IRebalanceAdapterBase`|Rebalance adapter for the LeverageToken|


### getLeverageTokenConfig

Returns the entire configuration for a LeverageToken


```solidity
function getLeverageTokenConfig(ILeverageToken token) external view returns (LeverageTokenConfig memory config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get config for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`config`|`LeverageTokenConfig`|LeverageToken configuration|


### getLeverageTokenInitialCollateralRatio

Returns the initial collateral ratio for a LeverageToken

*Initial collateral ratio is followed when the LeverageToken has no shares and on deposits when debt is 0.*


```solidity
function getLeverageTokenInitialCollateralRatio(ILeverageToken token)
    external
    view
    returns (uint256 initialCollateralRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get initial collateral ratio for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`initialCollateralRatio`|`uint256`|Initial collateral ratio for the LeverageToken|


### getLeverageTokenState

Returns all data required to describe current LeverageToken state - collateral, debt, equity and collateral ratio


```solidity
function getLeverageTokenState(ILeverageToken token) external view returns (LeverageTokenState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to query state for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LeverageTokenState`|LeverageToken state|


### createNewLeverageToken

Creates a new LeverageToken with the given config


```solidity
function createNewLeverageToken(LeverageTokenConfig memory config, string memory name, string memory symbol)
    external
    returns (ILeverageToken token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`config`|`LeverageTokenConfig`|Configuration of the LeverageToken|
|`name`|`string`|Name of the LeverageToken|
|`symbol`|`string`|Symbol of the LeverageToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|Address of the new LeverageToken|


### previewDeposit

Previews deposit function call and returns all required data

*Sender should approve leverage manager to spend collateralToAdd amount of collateral asset*


```solidity
function previewDeposit(ILeverageToken token, uint256 equityInCollateralAsset)
    external
    view
    returns (ActionData memory previewData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Equity to deposit denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`previewData`|`ActionData`|Preview data for deposit - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend, this includes any fees - debtToBorrow Amount of debt that will be borrowed and sent to sender - equity Amount of equity that will be deposited before fees, denominated in collateral asset - shares Amount of shares that will be minted to the sender - tokenFee Amount of collateral asset that will be charged for the deposit to the leverage token - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury|


### previewWithdraw

Previews withdraw function call and returns all required data

*Sender should approve leverage manager to spend debtToRepay amount of debt asset*


```solidity
function previewWithdraw(ILeverageToken token, uint256 equityInCollateralAsset)
    external
    view
    returns (ActionData memory previewData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview withdraw for|
|`equityInCollateralAsset`|`uint256`|Equity to withdraw denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`previewData`|`ActionData`|Preview data for withdraw - collateralToRemove Amount of collateral that will be removed from the LeverageToken and sent to the sender - debtToRepay Amount of debt that will be taken from sender and repaid to the LeverageToken - equity Amount of equity that will be withdrawn before fees, denominated in collateral asset - shares Amount of shares that will be burned from sender - tokenFee Amount of collateral asset that will be charged for the withdraw to the leverage token - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury|


### deposit

Deposits equity into a LeverageToken and mints shares to the sender


```solidity
function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken to deposit into|
|`equityInCollateralAsset`|`uint256`|The amount of equity to deposit denominated in the collateral asset of the LeverageToken|
|`minShares`|`uint256`|The minimum amount of shares to mint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the deposit - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - equity Amount of equity that was deposited before fees, denominated in collateral asset - shares Amount of shares minted to the sender - tokenFee Amount of collateral that was charged for the deposit to the leverage token - treasuryFee Amount of collateral that was charged for the deposit to the treasury|


### withdraw

Withdraws equity from a LeverageToken and burns shares from sender


```solidity
function withdraw(ILeverageToken token, uint256 equityInCollateralAsset, uint256 maxShares)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken to withdraw from|
|`equityInCollateralAsset`|`uint256`|The amount of equity to withdraw denominated in the collateral asset of the LeverageToken|
|`maxShares`|`uint256`|The maximum amount of shares to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the withdraw - collateral Amount of collateral that was removed from LeverageToken and sent to sender - debt Amount of debt that was repaid to LeverageToken, taken from sender - equity Amount of equity that was withdrawn before fees, denominated in collateral asset - shares Amount of the sender's shares that were burned for the withdrawal - tokenFee Amount of collateral that was charged for the withdraw to the leverage token - treasuryFee Amount of collateral that was charged for the withdraw to the treasury|


### rebalance

Rebalances LeverageTokens based on provided actions

*Anyone can call this function. At the end function will just check if all effected LeverageTokens are in the
better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
to specify tokens that he wants to receive*

*Note: If the sender specifies less tokensOut than the maximum amount they can retrieve for their specified
rebalance actions, the rebalance will still be successful. The remaining amount that could have been taken
out can be claimed by anyone by executing rebalance with that remaining amount in tokensOut.*


```solidity
function rebalance(
    RebalanceAction[] calldata actions,
    TokenTransfer[] calldata tokensIn,
    TokenTransfer[] calldata tokensOut
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actions`|`RebalanceAction[]`|Array of rebalance actions to execute (add collateral, remove collateral, borrow or repay)|
|`tokensIn`|`TokenTransfer[]`|Array of tokens to transfer in. Transfer from caller to the LeverageManager contract|
|`tokensOut`|`TokenTransfer[]`|Array of tokens to transfer out. Transfer from the LeverageManager contract to caller|


## Events
### LeverageManagerInitialized
Event emitted when the LeverageManager is initialized


```solidity
event LeverageManagerInitialized(IBeaconProxyFactory leverageTokenFactory);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageTokenFactory`|`IBeaconProxyFactory`|The factory for creating new LeverageTokens|

### LeverageTokenCreated
Event emitted when a new LeverageToken is created


```solidity
event LeverageTokenCreated(
    ILeverageToken indexed token, IERC20 collateralAsset, IERC20 debtAsset, LeverageTokenConfig config
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The new LeverageToken|
|`collateralAsset`|`IERC20`|The collateral asset of the LeverageToken|
|`debtAsset`|`IERC20`|The debt asset of the LeverageToken|
|`config`|`LeverageTokenConfig`|The config of the LeverageToken|

### Deposit
Event emitted when a user deposits assets into a LeverageToken


```solidity
event Deposit(ILeverageToken indexed token, address indexed sender, ActionData actionData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken|
|`sender`|`address`|The sender of the deposit|
|`actionData`|`ActionData`|The action data of the deposit|

### Withdraw
Event emitted when a user withdraws assets from a LeverageToken


```solidity
event Withdraw(ILeverageToken indexed token, address indexed sender, ActionData actionData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken|
|`sender`|`address`|The sender of the withdraw|
|`actionData`|`ActionData`|The action data of the withdraw|

## Errors
### InvalidLeverageTokenAssets
Error thrown when someone tries to set zero address for collateral or debt asset when creating a LeverageToken


```solidity
error InvalidLeverageTokenAssets();
```

### InvalidCollateralRatios
Error thrown when collateral ratios are invalid for an action


```solidity
error InvalidCollateralRatios();
```

### SlippageTooHigh
Error thrown when slippage is too high during deposit/withdraw


```solidity
error SlippageTooHigh(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual amount of tokens received|
|`expected`|`uint256`|The expected amount of tokens to receive|

### NotRebalancer
Error thrown when caller is not authorized to rebalance


```solidity
error NotRebalancer(ILeverageToken token, address caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken to rebalance|
|`caller`|`address`|The caller of the rebalance function|

### LeverageTokenNotEligibleForRebalance
Error thrown when a LeverageToken is not eligible for rebalance


```solidity
error LeverageTokenNotEligibleForRebalance(ILeverageToken token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken that is not eligible for rebalance|

### InvalidLeverageTokenStateAfterRebalance
Error thrown when a LeverageToken's state after rebalance is invalid


```solidity
error InvalidLeverageTokenStateAfterRebalance(ILeverageToken token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken that has invalid state after rebalance|

