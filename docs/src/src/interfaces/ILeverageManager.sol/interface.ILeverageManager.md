# ILeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/5f47bb45d300f9abc725e6a08e82ac80219f0e37/src/interfaces/ILeverageManager.sol)

**Inherits:**
[IFeeManager](/src/interfaces/IFeeManager.sol/interface.IFeeManager.md)


## Functions
### BASE_RATIO

Returns the base collateral ratio


```solidity
function BASE_RATIO() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|baseRatio Base collateral ratio|


### convertCollateralToDebt

Converts an amount of collateral to an amount of debt for a LeverageToken, based on the current
collateral ratio of the LeverageToken

*For deposits/mints, Math.Rounding.Floor should be used. For withdraws/redeems, Math.Rounding.Ceil should be used.*


```solidity
function convertCollateralToDebt(ILeverageToken token, uint256 collateral, Math.Rounding rounding)
    external
    view
    returns (uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert collateral to debt for|
|`collateral`|`uint256`|Amount of collateral to convert to debt|
|`rounding`|`Math.Rounding`|Rounding mode to use for the conversion|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Amount of debt that correspond to the collateral|


### convertCollateralToShares

Converts an amount of collateral to an amount of shares for a LeverageToken, based on the current
collateral ratio of the LeverageToken

*For deposits/mints, Math.Rounding.Floor should be used. For withdraws/redeems, Math.Rounding.Ceil should be used.*


```solidity
function convertCollateralToShares(ILeverageToken token, uint256 collateral, Math.Rounding rounding)
    external
    view
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert collateral to shares for|
|`collateral`|`uint256`|Amount of collateral to convert to shares|
|`rounding`|`Math.Rounding`|Rounding mode to use for the conversion|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of shares that correspond to the collateral|


### convertDebtToCollateral

Converts an amount of debt to an amount of collateral for a LeverageToken, based on the current
collateral ratio of the LeverageToken

*For deposits/mints, Math.Rounding.Ceil should be used. For withdraws/redeems, Math.Rounding.Floor should be used.*


```solidity
function convertDebtToCollateral(ILeverageToken token, uint256 debt, Math.Rounding rounding)
    external
    view
    returns (uint256 collateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert debt to collateral for|
|`debt`|`uint256`|Amount of debt to convert to collateral|
|`rounding`|`Math.Rounding`|Rounding mode to use for the conversion|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Amount of collateral that correspond to the debt amount|


### convertSharesToCollateral

Converts an amount of shares to an amount of collateral for a LeverageToken, based on the current
collateral ratio of the LeverageToken

*For deposits/mints, Math.Rounding.Ceil should be used. For withdraws/redeems, Math.Rounding.Floor should be used.*


```solidity
function convertSharesToCollateral(ILeverageToken token, uint256 shares, Math.Rounding rounding)
    external
    view
    returns (uint256 collateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert shares to collateral for|
|`shares`|`uint256`|Amount of shares to convert to collateral|
|`rounding`|`Math.Rounding`|Rounding mode to use for the conversion|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Amount of collateral that correspond to the shares|


### convertSharesToDebt

Converts an amount of shares to an amount of debt for a LeverageToken, based on the current
collateral ratio of the LeverageToken

*For deposits/mints, Math.Rounding.Floor should be used. For withdraws/redeems, Math.Rounding.Ceil should be used.*


```solidity
function convertSharesToDebt(ILeverageToken token, uint256 shares, Math.Rounding rounding)
    external
    view
    returns (uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert shares to debt for|
|`shares`|`uint256`|Amount of shares to convert to debt|
|`rounding`|`Math.Rounding`|Rounding mode to use for the conversion|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Amount of debt that correspond to the shares|


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

*Initial collateral ratio is followed when the LeverageToken has no shares and on mints when debt is 0.*


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


### previewDeposit

Previews deposit function call and returns all required data

*Sender should approve leverage manager to spend collateral amount of collateral asset*


```solidity
function previewDeposit(ILeverageToken token, uint256 collateral) external view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`collateral`|`uint256`|Amount of collateral to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for deposit - collateral Amount of collateral that will be added to the LeverageToken and sent to the receiver - debt Amount of debt that will be borrowed and sent to the receiver - shares Amount of shares that will be minted to the receiver - tokenFee Amount of shares that will be charged for the deposit that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the deposit that are given to the treasury|


### previewMint

Previews mint function call and returns all required data

*Sender should approve leverage manager to spend collateral amount of collateral asset*


```solidity
function previewMint(ILeverageToken token, uint256 shares) external view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview mint for|
|`shares`|`uint256`|Amount of shares to mint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for mint - collateral Amount of collateral that will be added to the LeverageToken and sent to the receiver - debt Amount of debt that will be borrowed and sent to the receiver - shares Amount of shares that will be minted to the receiver - tokenFee Amount of shares that will be charged for the mint that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the mint that are given to the treasury|


### previewRedeem

Previews redeem function call and returns all required data

*Sender should approve LeverageManager to spend debt amount of debt asset*


```solidity
function previewRedeem(ILeverageToken token, uint256 shares) external view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview redeem for|
|`shares`|`uint256`|Amount of shares to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for redeem - collateral Amount of collateral that will be removed from the LeverageToken and sent to the sender - debt Amount of debt that will be taken from sender and repaid to the LeverageToken - shares Amount of shares that will be burned from sender - tokenFee Amount of shares that will be charged for the redeem that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the redeem that are given to the treasury|


### previewWithdraw

Previews withdraw function call and returns all required data

*Sender should approve LeverageManager to spend debt amount of debt asset*


```solidity
function previewWithdraw(ILeverageToken token, uint256 collateral) external view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview withdraw for|
|`collateral`|`uint256`|Amount of collateral to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for withdraw - collateral Amount of collateral that will be removed from the LeverageToken and sent to the sender - debt Amount of debt that will be taken from sender and repaid to the LeverageToken - shares Amount of shares that will be burned from sender - tokenFee Amount of shares that will be charged for the redeem that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the redeem that are given to the treasury|


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


### deposit

Deposits collateral into a LeverageToken and mints shares to the sender

*Sender should approve leverage manager to spend collateral amount of collateral asset*


```solidity
function deposit(ILeverageToken token, uint256 collateral, uint256 minShares) external returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to deposit into|
|`collateral`|`uint256`|Amount of collateral to deposit|
|`minShares`|`uint256`|Minimum number of shares to mint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|depositData Action data for the deposit - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - shares Amount of shares minted to the sender - tokenFee Amount of shares that was charged for the deposit that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the deposit that are given to the treasury|


### mint

Mints shares of a LeverageToken to the sender

*Sender should approve leverage manager to spend collateral amount of collateral asset, which can be
previewed with previewMint*


```solidity
function mint(ILeverageToken token, uint256 shares, uint256 maxCollateral) external returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to mint shares for|
|`shares`|`uint256`|Amount of shares to mint|
|`maxCollateral`|`uint256`|Maximum amount of collateral to use for minting|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|mintData Action data for the mint - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - shares Amount of shares minted to the sender - tokenFee Amount of shares that was charged for the mint that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the mint that are given to the treasury|


### redeem

Redeems equity from a LeverageToken and burns shares from sender


```solidity
function redeem(ILeverageToken token, uint256 shares, uint256 minCollateral)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken to redeem from|
|`shares`|`uint256`|The amount of shares to redeem|
|`minCollateral`|`uint256`|The minimum amount of collateral to receive|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the redeem - collateral Amount of collateral that was removed from LeverageToken and sent to sender - debt Amount of debt that was repaid to LeverageToken, taken from sender - shares Amount of the sender's shares that were burned for the redeem - tokenFee Amount of shares that was charged for the redeem that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the redeem that are given to the treasury|


### rebalance

Rebalances a LeverageToken based on provided actions

*Anyone can call this function. At the end function will just check if the affected LeverageToken is in a
better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
to specify tokens that he wants to receive*

*Note: If the sender specifies less amountOut than the maximum amount they can retrieve for their specified
rebalance actions, the rebalance will still be successful. The remaining amount that could have been taken
out can be claimed by anyone by executing rebalance with that remaining amount in amountOut.*


```solidity
function rebalance(
    ILeverageToken leverageToken,
    RebalanceAction[] calldata actions,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 amountIn,
    uint256 amountOut
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|LeverageToken to rebalance|
|`actions`|`RebalanceAction[]`|Rebalance actions to execute (add collateral, remove collateral, borrow or repay)|
|`tokenIn`|`IERC20`|Token to transfer in. Transfer from caller to the LeverageManager contract|
|`tokenOut`|`IERC20`|Token to transfer out. Transfer from the LeverageManager contract to caller|
|`amountIn`|`uint256`|Amount of tokenIn to transfer in|
|`amountOut`|`uint256`|Amount of tokenOut to transfer out|


### withdraw

Withdraws collateral from a LeverageToken and burns shares from sender


```solidity
function withdraw(ILeverageToken token, uint256 collateral, uint256 maxShares)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken to withdraw from|
|`collateral`|`uint256`|The amount of collateral to withdraw|
|`maxShares`|`uint256`|The maximum amount of shares to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the withdraw - collateral Amount of collateral that was removed from LeverageToken and sent to sender - debt Amount of debt that was repaid to LeverageToken, taken from sender - shares Amount of the sender's shares that were burned for the withdraw - tokenFee Amount of shares that was charged for the withdraw that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the withdraw that are given to the treasury|


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

### Mint
Event emitted when a user mints LeverageToken shares


```solidity
event Mint(ILeverageToken indexed token, address indexed sender, ActionData actionData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken|
|`sender`|`address`|The sender of the mint|
|`actionData`|`ActionData`|The action data of the mint|

### Rebalance
Event emitted when a user rebalances a LeverageToken


```solidity
event Rebalance(
    ILeverageToken indexed token,
    address indexed sender,
    LeverageTokenState stateBefore,
    LeverageTokenState stateAfter,
    RebalanceAction[] actions
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken|
|`sender`|`address`|The sender of the rebalance|
|`stateBefore`|`LeverageTokenState`|The state of the LeverageToken before the rebalance|
|`stateAfter`|`LeverageTokenState`|The state of the LeverageToken after the rebalance|
|`actions`|`RebalanceAction[]`|The actions that were taken|

### Redeem
Event emitted when a user redeems LeverageToken shares


```solidity
event Redeem(ILeverageToken indexed token, address indexed sender, ActionData actionData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken|
|`sender`|`address`|The sender of the redeem|
|`actionData`|`ActionData`|The action data of the redeem|

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
Error thrown when slippage is too high during mint/redeem


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

### InvalidLeverageTokenInitialCollateralRatio
Error thrown when a LeverageToken's initial collateral ratio is invalid (must be greater than the base ratio)


```solidity
error InvalidLeverageTokenInitialCollateralRatio(uint256 initialCollateralRatio);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialCollateralRatio`|`uint256`|The initial collateral ratio that is invalid|

### InvalidLeverageTokenStateAfterRebalance
Error thrown when a LeverageToken's state after rebalance is invalid


```solidity
error InvalidLeverageTokenStateAfterRebalance(ILeverageToken token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|The LeverageToken that has invalid state after rebalance|

### LeverageTokenNotEligibleForRebalance
Error thrown when attempting to rebalance a LeverageToken that is not eligible for rebalance


```solidity
error LeverageTokenNotEligibleForRebalance();
```

