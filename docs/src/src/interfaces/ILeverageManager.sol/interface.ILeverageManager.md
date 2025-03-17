# ILeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/ILeverageManager.sol)

**Inherits:**
[IFeeManager](/src/interfaces/IFeeManager.sol/interface.IFeeManager.md)


## Functions
### getStrategyTokenFactory

Returns factory for creating new strategy tokens


```solidity
function getStrategyTokenFactory() external view returns (IBeaconProxyFactory factory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`IBeaconProxyFactory`|Factory for creating new strategy tokens|


### getIsLendingAdapterUsed

Returns if lending adapter is in use by some other strategy


```solidity
function getIsLendingAdapterUsed(address adapter) external view returns (bool isUsed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|Adapter to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isUsed`|`bool`|True if adapter is used by some strategy|


### getStrategyLendingAdapter

Returns lending adapter for the strategy


```solidity
function getStrategyLendingAdapter(IStrategy strategy) external view returns (ILendingAdapter adapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get lending adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`ILendingAdapter`|Lending adapter for the strategy|


### getStrategyCollateralAsset

Returns collateral asset for the strategy


```solidity
function getStrategyCollateralAsset(IStrategy strategy) external view returns (IERC20 collateralAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get collateral asset for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateralAsset`|`IERC20`|Collateral asset for the strategy|


### getStrategyDebtAsset

Returns debt asset for the strategy


```solidity
function getStrategyDebtAsset(IStrategy strategy) external view returns (IERC20 debtAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get debt asset for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debtAsset`|`IERC20`|Debt asset for the strategy|


### getStrategyRebalanceRewardDistributor

Returns module for distributing rewards for rebalancing strategy


```solidity
function getStrategyRebalanceRewardDistributor(IStrategy strategy)
    external
    view
    returns (IRebalanceRewardDistributor distributor);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get module for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`distributor`|`IRebalanceRewardDistributor`|Module for distributing rewards for rebalancing strategy|


### getStrategyRebalanceWhitelist

Returns rebalance whitelist module for strategy


```solidity
function getStrategyRebalanceWhitelist(IStrategy strategy) external view returns (IRebalanceWhitelist whitelist);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get rebalance whitelist for|


### getStrategyCollateralRatios

Returns leverage config for a strategy including min, max and target


```solidity
function getStrategyCollateralRatios(IStrategy strategy) external view returns (CollateralRatios memory ratios);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get leverage config for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratios`|`CollateralRatios`|Collateral ratios for the strategy|


### getStrategyTargetCollateralRatio

Returns target ratio for a strategy


```solidity
function getStrategyTargetCollateralRatio(IStrategy strategy) external view returns (uint256 targetRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get target ratio for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`targetRatio`|`uint256`|Target ratio|


### getStrategyConfig

Returns entire configuration for given strategy


```solidity
function getStrategyConfig(IStrategy strategy) external view returns (StrategyConfig memory config);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Address of the strategy to get config for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`config`|`StrategyConfig`|Strategy configuration|


### setStrategyTokenFactory

Sets factory for creating new strategy tokens

*Only DEFAULT_ADMIN_ROLE can call this function*


```solidity
function setStrategyTokenFactory(address factory) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`address`|Factory to set|


### createNewStrategy

Creates new strategy with given config


```solidity
function createNewStrategy(StrategyConfig memory strategyConfig, string memory name, string memory symbol)
    external
    returns (IStrategy strategy);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategyConfig`|`StrategyConfig`|Configuration of the strategy|
|`name`|`string`|Name of the strategy token|
|`symbol`|`string`|Symbol of the strategy token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Address of the new strategy|


### previewDeposit

Previews deposit function call and returns all required data

*Sender should approve leverage manager to spend collateralToAdd amount of collateral asset*


```solidity
function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset)
    external
    view
    returns (ActionData memory previewData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Equity to deposit denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`previewData`|`ActionData`|Preview data for deposit - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend, this includes any fees - debtToBorrow Amount of debt that will be borrowed and sent to sender - equityInCollateralAsset Amount of equity that will be deposited before fees - shares Amount of shares that will be minted to the sender - strategyFee Amount of collateral asset that will be charged for the deposit to the strategy - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury|


### previewWithdraw

Previews withdraw function call and returns all required data

*Sender should approve leverage manager to spend debtToRepay amount of debt asset*


```solidity
function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset)
    external
    view
    returns (ActionData memory previewData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to preview withdraw for|
|`equityInCollateralAsset`|`uint256`|Equity to withdraw denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`previewData`|`ActionData`|Preview data for withdraw - collateralToRemove Amount of collateral that will be removed from the strategy and sent to the sender - debtToRepay Amount of debt that will be taken from sender and repaid to the strategy - equityInCollateralAsset Amount of equity that will be withdrawn before fees - shares Amount of shares that will be burned from sender - strategyFee Amount of collateral asset that will be charged for the withdraw to the strategy - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury|


### deposit

Deposits equity into a strategy and mints shares to the sender


```solidity
function deposit(IStrategy strategy, uint256 equityInCollateralAsset, uint256 minShares)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|The strategy to deposit into|
|`equityInCollateralAsset`|`uint256`|The amount of equity to deposit denominated in the collateral asset of the strategy|
|`minShares`|`uint256`|The minimum amount of shares to mint|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the deposit - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - equityInCollateralAsset Amount of equity that was deposited before fees - shares Amount of shares minted to the sender - strategyFee Amount of collateral that was charged for the deposit to the strategy - treasuryFee Amount of collateral that was charged for the deposit to the treasury|


### withdraw

Withdraws equity from a strategy and burns shares from sender


```solidity
function withdraw(IStrategy strategy, uint256 equityInCollateralAsset, uint256 maxShares)
    external
    returns (ActionData memory actionData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|The strategy to withdraw from|
|`equityInCollateralAsset`|`uint256`|The amount of equity to withdraw denominated in the collateral asset of the strategy|
|`maxShares`|`uint256`|The maximum amount of shares to burn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`actionData`|`ActionData`|Data about the withdraw - collateral Amount of collateral that was removed from strategy and sent to sender - debt Amount of debt that was repaid to strategy, taken from sender - equityInCollateralAsset Amount of equity that was withdrawn before fees - shares Amount of the sender's shares that were burned for the withdrawal - strategyFee Amount of collateral that was charged for the withdraw to the strategy - treasuryFee Amount of collateral that was charged for the withdraw to the treasury|


### rebalance

Rebalances strategies based on provided actions

*Anyone can call this function. At the end function will just check if all effected strategies are in the
better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
to specify tokens that he wants to receive*


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
|`tokensIn`|`TokenTransfer[]`|Array of tokens to transfer in. Transfer from caller to leverage manager contract|
|`tokensOut`|`TokenTransfer[]`|Array of tokens to transfer out. Transfer from leverage manager contract to caller|


## Events
### StrategyTokenFactorySet
Event emitted when strategy token factory is set


```solidity
event StrategyTokenFactorySet(address factory);
```

### StrategyCreated
Event emitted when new strategy is created


```solidity
event StrategyCreated(IStrategy indexed strategy, IERC20 collateralAsset, IERC20 debtAsset, StrategyConfig config);
```

### Deposit
Event emitted when user deposits assets into strategy


```solidity
event Deposit(IStrategy indexed strategy, address indexed sender, ActionData actionData);
```

### Withdraw
Event emitted when user withdraws assets from strategy


```solidity
event Withdraw(IStrategy indexed strategy, address indexed sender, ActionData actionData);
```

## Errors
### LendingAdapterAlreadyInUse
Error thrown when someone tries to create strategy with lending adapter that already exists


```solidity
error LendingAdapterAlreadyInUse(address adapter);
```

### InvalidStrategyAssets
Error thrown when someone tries to set zero address for collateral or debt asset when creating strategy


```solidity
error InvalidStrategyAssets();
```

### InvalidCollateralRatios
Error thrown when collateral ratios are invalid


```solidity
error InvalidCollateralRatios();
```

### SlippageTooHigh
Error thrown when slippage is too high during mint/redeem


```solidity
error SlippageTooHigh(uint256 actual, uint256 expected);
```

### NotRebalancer
Error thrown when caller is whitelisted for rebalance action


```solidity
error NotRebalancer(IStrategy strategy, address caller);
```

### StrategyNotEligibleForRebalance
Error thrown when strategy is not eligible for rebalance


```solidity
error StrategyNotEligibleForRebalance(IStrategy strategy);
```

### CollateralRatioInvalid
Error thrown when collateral ratio after rebalance is worse than before rebalance


```solidity
error CollateralRatioInvalid();
```

### ExposureDirectionChanged
Error thrown when collateral ratio after rebalance is on the opposite side of target ratio than before rebalance


```solidity
error ExposureDirectionChanged();
```

### EquityLossTooBig
Error thrown when equity loss on rebalance is too big


```solidity
error EquityLossTooBig();
```

## Structs
### StrategyConfig
*Struct that contains entire strategy config*


```solidity
struct StrategyConfig {
    ILendingAdapter lendingAdapter;
    uint256 minCollateralRatio;
    uint256 maxCollateralRatio;
    uint256 targetCollateralRatio;
    IRebalanceRewardDistributor rebalanceRewardDistributor;
    IRebalanceWhitelist rebalanceWhitelist;
}
```

