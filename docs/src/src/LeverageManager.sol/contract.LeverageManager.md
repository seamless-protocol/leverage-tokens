# LeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/LeverageManager.sol)

**Inherits:**
[ILeverageManager](/src/interfaces/ILeverageManager.sol/interface.ILeverageManager.md), AccessControlUpgradeable, [FeeManager](/src/FeeManager.sol/contract.FeeManager.md), UUPSUpgradeable


## State Variables
### BASE_RATIO

```solidity
uint256 public constant BASE_RATIO = 1e8;
```


### DECIMALS_OFFSET

```solidity
uint256 public constant DECIMALS_OFFSET = 0;
```


### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### MANAGER_ROLE

```solidity
bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
```


## Functions
### _getLeverageManagerStorage


```solidity
function _getLeverageManagerStorage() internal pure returns (LeverageManagerStorage storage $);
```

### initialize


```solidity
function initialize(address initialAdmin) external initializer;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### getStrategyTokenFactory

Returns factory for creating new strategy tokens


```solidity
function getStrategyTokenFactory() public view returns (IBeaconProxyFactory factory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`IBeaconProxyFactory`|Factory for creating new strategy tokens|


### getIsLendingAdapterUsed

Returns if lending adapter is in use by some other strategy


```solidity
function getIsLendingAdapterUsed(address lendingAdapter) public view returns (bool isUsed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingAdapter`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isUsed`|`bool`|True if adapter is used by some strategy|


### getStrategyCollateralAsset

Returns collateral asset for the strategy


```solidity
function getStrategyCollateralAsset(IStrategy strategy) public view returns (IERC20 collateralAsset);
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
function getStrategyDebtAsset(IStrategy strategy) public view returns (IERC20 debtAsset);
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
    public
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


```solidity
function getStrategyRebalanceWhitelist(IStrategy strategy) public view returns (IRebalanceWhitelist whitelist);
```

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


### getStrategyLendingAdapter

Returns lending adapter for the strategy


```solidity
function getStrategyLendingAdapter(IStrategy strategy) public view returns (ILendingAdapter adapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get lending adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`ILendingAdapter`|Lending adapter for the strategy|


### getStrategyCollateralRatios

Returns leverage config for a strategy including min, max and target


```solidity
function getStrategyCollateralRatios(IStrategy strategy) public view returns (CollateralRatios memory ratios);
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
function getStrategyTargetCollateralRatio(IStrategy strategy) public view returns (uint256 targetCollateralRatio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to get target ratio for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`targetCollateralRatio`|`uint256`|targetRatio Target ratio|


### setStrategyTokenFactory

Sets factory for creating new strategy tokens

*Only DEFAULT_ADMIN_ROLE can call this function*


```solidity
function setStrategyTokenFactory(address factory) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`address`|Factory to set|


### createNewStrategy

Creates new strategy with given config


```solidity
function createNewStrategy(StrategyConfig calldata strategyConfig, string memory name, string memory symbol)
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
function previewDeposit(IStrategy strategy, uint256 equityInCollateralAsset) public view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Equity to deposit denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for deposit - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend, this includes any fees - debtToBorrow Amount of debt that will be borrowed and sent to sender - equityInCollateralAsset Amount of equity that will be deposited before fees - shares Amount of shares that will be minted to the sender - strategyFee Amount of collateral asset that will be charged for the deposit to the strategy - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury|


### previewWithdraw

Previews withdraw function call and returns all required data

*Sender should approve leverage manager to spend debtToRepay amount of debt asset*


```solidity
function previewWithdraw(IStrategy strategy, uint256 equityInCollateralAsset) public view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to preview withdraw for|
|`equityInCollateralAsset`|`uint256`|Equity to withdraw denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for withdraw - collateralToRemove Amount of collateral that will be removed from the strategy and sent to the sender - debtToRepay Amount of debt that will be taken from sender and repaid to the strategy - equityInCollateralAsset Amount of equity that will be withdrawn before fees - shares Amount of shares that will be burned from sender - strategyFee Amount of collateral asset that will be charged for the withdraw to the strategy - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury|


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


### _validateIsAuthorizedToRebalance

Validates if caller is allowed to rebalance strategy

*Caller is not allowed to rebalance strategy if they are not whitelisted in the strategy's rebalance whitelist module*


```solidity
function _validateIsAuthorizedToRebalance(IStrategy strategy) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to validate caller for|


### _validateRebalanceEligibility

Validates if strategy should be rebalanced

*Strategy should be rebalanced if it's collateral ratio is outside of the min/max range.
If strategy is not eligible for rebalance, function will revert*


```solidity
function _validateRebalanceEligibility(IStrategy strategy, uint256 currCollateralRatio) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to validate|
|`currCollateralRatio`|`uint256`|Current collateral ratio of the strategy|


### _validateStrategyStateAfterRebalance

Validates if strategy is in better state after rebalance

*Function checks if collateral ratio is closer to target ratio than it was before rebalance. Function also checks
if equity is not too much lower. Rebalancer is allowed to take percentage of equity when rebalancing strategy.
This percentage is considered as reward for rebalancer.*


```solidity
function _validateStrategyStateAfterRebalance(IStrategy strategy, StrategyState memory stateBefore) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to validate|
|`stateBefore`|`StrategyState`|State of the strategy before rebalance that includes collateral, debt, equity and collateral ratio|


### _validateCollateralRatioAfterRebalance

Validates collateral ratio after rebalance

*Collateral ratio after rebalance needs to be closer to target ratio than before rebalance. Also both collateral ratios
need to be on the same side. This means if strategy was overexposed before rebalance it can not be underexposed not and vice verse.*


```solidity
function _validateCollateralRatioAfterRebalance(
    IStrategy strategy,
    uint256 collateralRatioBefore,
    uint256 collateralRatioAfter
) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to validate ratio for|
|`collateralRatioBefore`|`uint256`|Collateral ratio before rebalance|
|`collateralRatioAfter`|`uint256`|Collateral ratio after rebalance|


### _validateEquityChange

Validates that strategy has enough equity after rebalance action


```solidity
function _validateEquityChange(IStrategy strategy, StrategyState memory stateBefore, StrategyState memory stateAfter)
    internal
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`||
|`stateBefore`|`StrategyState`|State of the strategy before rebalance|
|`stateAfter`|`StrategyState`|State of the strategy after rebalance|


### _convertToShares

Function that converts user's equity to shares

Function uses OZ formula for calculating shares

*Function should be used to calculate how much shares user should receive for their equity*


```solidity
function _convertToShares(IStrategy strategy, uint256 equityInCollateralAsset) internal view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to convert equity for|
|`equityInCollateralAsset`|`uint256`|Equity to convert to shares, denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Shares|


### _getStrategyState

Returns all data required to describe current strategy state - collateral, debt, equity and collateral ratio


```solidity
function _getStrategyState(IStrategy strategy) internal view returns (StrategyState memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to query state for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StrategyState`|state Strategy state|


### _previewAction

Previews parameters related to a deposit action

*If the strategy has zero total supply of shares (so the strategy does not hold any collateral or debt,
or holds some leftover dust after all shares are redeemed), then the preview will use the target
collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.*

*If action is deposit collateral will be rounded down and debt up, if action is withdraw collateral will be rounded up and debt down*


```solidity
function _previewAction(IStrategy strategy, uint256 equityInCollateralAsset, ExternalAction action)
    internal
    view
    returns (ActionData memory data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Amount of equity to add or withdraw, denominated in collateral asset|
|`action`|`ExternalAction`|Type of the action to preview, can be Deposit or Withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`ActionData`|Preview data for the action|


### _computeCollateralAndDebtForAction

Function that computes collateral and debt required by the position held by a strategy for a given action and an amount of equity to add / remove


```solidity
function _computeCollateralAndDebtForAction(IStrategy strategy, uint256 equityInCollateralAsset, ExternalAction action)
    internal
    view
    returns (uint256 collateral, uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to compute collateral and debt for|
|`equityInCollateralAsset`|`uint256`|Equity amount in collateral asset|
|`action`|`ExternalAction`|Action to compute collateral and debt for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Collateral to add / remove from the strategy|
|`debt`|`uint256`|Debt to borrow / repay to the strategy|


### _isElementInSlice

Function that checks if specific element has already been processed in the slice up to the given index

*This function is used to check if we already stored the state of the strategy before rebalance.
This function is used to check if strategy state has been already validated after rebalance*


```solidity
function _isElementInSlice(RebalanceAction[] calldata actions, IStrategy strategy, uint256 untilIndex)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actions`|`RebalanceAction[]`|Entire array to go through|
|`strategy`|`IStrategy`|Element to search for|
|`untilIndex`|`uint256`|Search until this specific index|


### _executeLendingAdapterAction

Executes action on lending adapter from specific strategy


```solidity
function _executeLendingAdapterAction(IStrategy strategy, ActionType actionType, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to execute action on|
|`actionType`|`ActionType`|Type of the action to execute|
|`amount`|`uint256`|Amount to execute action with|


### _transferTokens

Batched token transfer

*If from address is this smart contract it will use regular transfer function otherwise it will use transferFrom*


```solidity
function _transferTokens(TokenTransfer[] calldata transfers, address from, address to) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`transfers`|`TokenTransfer[]`|Array of transfer data. Transfer data consist of token to transfer and amount|
|`from`|`address`|Address to transfer tokens from|
|`to`|`address`|Address to transfer tokens to|


## Structs
### LeverageManagerStorage
*Struct containing all state for the LeverageManager contract*

**Note:**
storage-location: erc7201:seamless.contracts.storage.LeverageManager


```solidity
struct LeverageManagerStorage {
    IBeaconProxyFactory strategyTokenFactory;
    mapping(IStrategy strategy => ILeverageManager.StrategyConfig) config;
    mapping(address lendingAdapter => bool) isLendingAdapterUsed;
}
```

