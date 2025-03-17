# LeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/periphery/LeverageRouter.sol)

**Inherits:**
[ILeverageRouter](/src/interfaces/periphery/ILeverageRouter.sol/interface.ILeverageRouter.md)


## State Variables
### leverageManager
The Seamless LeverageManager contract


```solidity
ILeverageManager public immutable leverageManager;
```


### morpho
The Morpho core protocol contract


```solidity
IMorpho public immutable morpho;
```


### swapper
The swap adapter contract used to facilitate swaps


```solidity
ISwapAdapter public immutable swapper;
```


## Functions
### constructor

Creates a new LeverageRouter


```solidity
constructor(ILeverageManager _leverageManager, IMorpho _morpho, ISwapAdapter _swapper);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The Seamless LeverageManager contract|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|
|`_swapper`|`ISwapAdapter`|The Swapper contract|


### deposit

Deposit equity into a strategy

*Flash loans the collateral required to add the equity to the strategy, receives debt, then swaps the debt to the
strategy's collateral asset. The swapped assets and the sender's supplied collateral are used to repay the flash loan*


```solidity
function deposit(
    IStrategy strategy,
    uint256 equityInCollateralAsset,
    uint256 minShares,
    uint256 maxSwapCostInCollateralAsset,
    ISwapAdapter.SwapContext memory swapContext
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to deposit equity into|
|`equityInCollateralAsset`|`uint256`|The amount of equity to deposit into the strategy. Denominated in the collateral asset of the strategy|
|`minShares`|`uint256`|Minimum shares to receive from the deposit|
|`maxSwapCostInCollateralAsset`|`uint256`|The maximum amount of collateral from the sender to use to help repay the flash loan due to the swap of debt to collateral being unfavorable|
|`swapContext`|`ISwapAdapter.SwapContext`|Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)|


### withdraw

Withdraw equity from a strategy


```solidity
function withdraw(
    IStrategy strategy,
    uint256 equityInCollateralAsset,
    uint256 maxShares,
    uint256 maxSwapCostInCollateralAsset,
    ISwapAdapter.SwapContext memory swapContext
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strategy`|`IStrategy`|Strategy to withdraw equity from|
|`equityInCollateralAsset`|`uint256`|The amount of equity to withdraw from the strategy. Denominated in the collateral asset of the strategy|
|`maxShares`|`uint256`|Maximum shares to burn for the withdrawal|
|`maxSwapCostInCollateralAsset`|`uint256`|The maximum amount of equity received from the withdrawal from the strategy to use to help repay the debt flash loan due to the swap of debt to collateral being unfavorable|
|`swapContext`|`ISwapAdapter.SwapContext`|Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)|


### onMorphoFlashLoan

Morpho flash loan callback function


```solidity
function onMorphoFlashLoan(uint256 loanAmount, bytes calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`loanAmount`|`uint256`|Amount of asset flash loaned|
|`data`|`bytes`|Encoded data passed to `morpho.flashLoan`|


### _depositAndRepayMorphoFlashLoan

Executes the deposit of equity into a strategy and the swap of debt assets to the collateral asset
to repay the flash loan from Morpho


```solidity
function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`DepositParams`|Params for the deposit of equity into a strategy|
|`collateralLoanAmount`|`uint256`|Amount of collateral asset flash loaned|


### _withdrawAndRepayMorphoFlashLoan

Executes the withdrawal of equity from a strategy and the swap of collateral assets to the debt asset
to repay the flash loan from Morpho


```solidity
function _withdrawAndRepayMorphoFlashLoan(WithdrawParams memory params, uint256 debtLoanAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`WithdrawParams`|Params for the withdrawal of equity from a strategy|
|`debtLoanAmount`|`uint256`|Amount of debt asset flash loaned|


## Structs
### DepositParams
Deposit related parameters to pass to the Morpho flash loan callback handler for deposits


```solidity
struct DepositParams {
    IStrategy strategy;
    uint256 equityInCollateralAsset;
    uint256 minShares;
    uint256 maxSwapCostInCollateralAsset;
    address sender;
    ISwapAdapter.SwapContext swapContext;
}
```

### WithdrawParams
Withdraw related parameters to pass to the Morpho flash loan callback handler for withdrawals


```solidity
struct WithdrawParams {
    IStrategy strategy;
    uint256 equityInCollateralAsset;
    uint256 maxShares;
    uint256 maxSwapCostInCollateralAsset;
    address sender;
    ISwapAdapter.SwapContext swapContext;
}
```

### MorphoCallbackData
Morpho flash loan callback data to pass to the Morpho flash loan callback handler


```solidity
struct MorphoCallbackData {
    ExternalAction action;
    bytes data;
}
```

