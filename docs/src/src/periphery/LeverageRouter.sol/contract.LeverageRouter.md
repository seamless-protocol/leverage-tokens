# LeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/002c85336929e7b2f8b2193e3cb727fe9cf4b9e6/src/periphery/LeverageRouter.sol)

**Inherits:**
[ILeverageRouter](/src/interfaces/periphery/ILeverageRouter.sol/interface.ILeverageRouter.md)

*The LeverageRouter contract is an immutable periphery contract that facilitates the use of Morpho flash loans and a swap adapter
to deposit and withdraw equity from LeverageTokens.
The high-level deposit flow is as follows:
1. The user calls `deposit` with the amount of equity to deposit, the minimum amount of shares (LeverageTokens) to receive, the maximum
cost to the sender for the swap of debt to collateral during the deposit to help repay the flash loan, and the swap context.
2. The LeverageRouter will flash loan the required collateral asset from Morpho.
3. The LeverageRouter will use the flash loaned collateral and the equity from the sender for the deposit into the LeverageToken,
receiving LeverageTokens and debt in return.
4. The LeverageRouter will swap the debt received from the deposit to the collateral asset.
5. The LeverageRouter will use the swapped assets to repay the flash loan along with the collateral asset from the sender
(the maximum swap cost)
6. The LeverageRouter will transfer the LeverageTokens and any remaining collateral asset to the sender.
The high-level withdrawal flow is the same as the deposit flow, but in reverse.*


## State Variables
### leverageManager
The LeverageManager contract


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
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|
|`_swapper`|`ISwapAdapter`|The Swapper contract|


### deposit

Deposit equity into a LeverageToken

*Flash loans the collateral required to add the equity to the LeverageToken, receives debt, then swaps the debt to the
LeverageToken's collateral asset. The swapped assets and the sender's supplied collateral are used to repay the flash loan*


```solidity
function deposit(
    ILeverageToken token,
    uint256 equityInCollateralAsset,
    uint256 minShares,
    uint256 maxSwapCostInCollateralAsset,
    ISwapAdapter.SwapContext memory swapContext
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to deposit equity into|
|`equityInCollateralAsset`|`uint256`|The amount of equity to deposit into the LeverageToken. Denominated in the collateral asset of the LeverageToken|
|`minShares`|`uint256`|Minimum shares (LeverageTokens) to receive from the deposit|
|`maxSwapCostInCollateralAsset`|`uint256`|The maximum amount of collateral from the sender to use to help repay the flash loan due to the swap of debt to collateral being unfavorable|
|`swapContext`|`ISwapAdapter.SwapContext`|Swap context to use for the swap (which DEX to use, the route, tick spacing, etc.)|


### withdraw

Withdraw equity from a LeverageToken


```solidity
function withdraw(
    ILeverageToken token,
    uint256 equityInCollateralAsset,
    uint256 maxShares,
    uint256 maxSwapCostInCollateralAsset,
    ISwapAdapter.SwapContext memory swapContext
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to withdraw equity from|
|`equityInCollateralAsset`|`uint256`|The amount of equity to withdraw from the LeverageToken. Denominated in the collateral asset of the LeverageToken|
|`maxShares`|`uint256`|Maximum shares (LeverageTokens) to burn for the withdrawal|
|`maxSwapCostInCollateralAsset`|`uint256`|The maximum amount of equity received from the withdrawal from the LeverageToken to use to help repay the debt flash loan due to the swap of debt to collateral being unfavorable|
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

Executes the deposit of equity into a LeverageToken and the swap of debt assets to the collateral asset
to repay the flash loan from Morpho


```solidity
function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 collateralLoanAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`DepositParams`|Params for the deposit of equity into a LeverageToken|
|`collateralLoanAmount`|`uint256`|Amount of collateral asset flash loaned|


### _withdrawAndRepayMorphoFlashLoan

Executes the withdrawal of equity from a LeverageToken and the swap of collateral assets to the debt asset
to repay the flash loan from Morpho


```solidity
function _withdrawAndRepayMorphoFlashLoan(WithdrawParams memory params, uint256 debtLoanAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`WithdrawParams`|Params for the withdrawal of equity from a LeverageToken|
|`debtLoanAmount`|`uint256`|Amount of debt asset flash loaned|


## Structs
### DepositParams
Deposit related parameters to pass to the Morpho flash loan callback handler for deposits


```solidity
struct DepositParams {
    ILeverageToken token;
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
    ILeverageToken token;
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

