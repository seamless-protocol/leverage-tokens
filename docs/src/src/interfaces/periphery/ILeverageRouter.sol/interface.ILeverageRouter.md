# ILeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/periphery/ILeverageRouter.sol)


## Functions
### leverageManager

The Seamless LeverageManager contract


```solidity
function leverageManager() external view returns (ILeverageManager leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`leverageManager`|`ILeverageManager`|The Seamless LeverageManager contract|


### morpho

The Morpho core protocol contract


```solidity
function morpho() external view returns (IMorpho _morpho);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


### swapper

The swap adapter contract used to facilitate swaps


```solidity
function swapper() external view returns (ISwapAdapter _swapper);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_swapper`|`ISwapAdapter`|The swap adapter contract|


### deposit

Deposit equity into a strategy

*Flash loans the collateral required to add the equity to the strategy, receives debt, then swaps the debt to the
strategy's collateral asset. The swapped assets and the sender's supplied collateral are used to repay the flash loan*

*The sender should approve the LeverageRouter to spend an amount of collateral assets greater than the equity being added
to facilitate the deposit in the case that the deposit requires additional collateral to cover swap slippage when swapping
debt to collateral to repay the flash loan. The approved amount should equal at least `equityInCollateralAsset + maxSwapCostInCollateralAsset`.
To see the preview of the deposit, `LeverageRouter.leverageManager().previewDeposit(...)` can be used.*


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


## Errors
### MaxSwapCostExceeded
Error thrown when the cost of a swap exceeds the maximum allowed cost


```solidity
error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);
```

### Unauthorized
Error thrown when the caller is not authorized to call a function


```solidity
error Unauthorized();
```

