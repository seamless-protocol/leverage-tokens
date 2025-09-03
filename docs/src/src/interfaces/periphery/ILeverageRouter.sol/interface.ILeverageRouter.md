# ILeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6fd46c53a22afa8918e99c47589c9bd10722b593/src/interfaces/periphery/ILeverageRouter.sol)


## Functions
### convertEquityToCollateral

Converts an amount of equity to an amount of collateral for a LeverageToken, based on the current
collateral ratio of the LeverageToken


```solidity
function convertEquityToCollateral(ILeverageToken token, uint256 equityInCollateralAsset)
    external
    view
    returns (uint256 collateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert equity to collateral for|
|`equityInCollateralAsset`|`uint256`|Amount of equity to convert to collateral, denominated in the collateral asset of the LeverageToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Amount of collateral that correspond to the equity amount|


### leverageManager

The LeverageManager contract


```solidity
function leverageManager() external view returns (ILeverageManager _leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|


### morpho

The Morpho core protocol contract


```solidity
function morpho() external view returns (IMorpho _morpho);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


### previewDeposit

Previews the deposit function call for an amount of equity and returns all required data


```solidity
function previewDeposit(ILeverageToken token, uint256 collateralFromSender) external view returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`collateralFromSender`|`uint256`|The amount of collateral from the sender to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for deposit - collateral Total amount of collateral that will be added to the LeverageToken (including collateral from swapping flash loaned debt) - debt Amount of debt that will be borrowed - shares Amount of shares that will be minted - tokenFee Amount of shares that will be charged for the deposit that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the deposit that are given to the treasury|


### deposit

Deposits collateral into a LeverageToken and mints shares to the sender. Any surplus debt received from
the deposit of (collateralFromSender + debt swapped to collateral) is given to the sender.

*Before each external call, the target contract is approved to spend flashLoanAmount of the debt asset*


```solidity
function deposit(
    ILeverageToken leverageToken,
    uint256 collateralFromSender,
    uint256 flashLoanAmount,
    uint256 minShares,
    Call[] calldata swapCalls
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|LeverageToken to deposit into|
|`collateralFromSender`|`uint256`|Collateral asset amount from the sender to deposit|
|`flashLoanAmount`|`uint256`|Amount of debt to flash loan, which is swapped to collateral and used to deposit into the LeverageToken|
|`minShares`|`uint256`|Minimum number of shares expected to be received by the sender|
|`swapCalls`|`Call[]`|External calls to execute for the swap of flash loaned debt to collateral for the LeverageToken deposit|


### redeem

Redeems an amount of shares of a LeverageToken and transfers collateral asset to the sender, using arbitrary
calldata for the swap of collateral from the redemption to debt to repay the flash loan. Any surplus debt assets
after repaying the flash loan are given to the sender along with the remaining collateral asset.


```solidity
function redeem(ILeverageToken token, uint256 shares, uint256 minCollateralForSender, Call[] calldata swapCalls)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to redeem from|
|`shares`|`uint256`|Amount of shares to redeem|
|`minCollateralForSender`|`uint256`|Minimum amount of collateral for the sender to receive|
|`swapCalls`|`Call[]`|External calls to execute for the swap of collateral from the redemption to debt to repay the flash loan|


### redeemWithVelora

Redeems an amount of shares of a LeverageToken and transfers collateral asset to the sender, using Velora
for the required swap of collateral from the redemption to debt to repay the flash loan

*The calldata should be for using Velora for an exact output swap of the collateral asset to the debt asset
for the debt amount flash loaned, which is equal to the amount of debt removed from the LeverageToken for the
redemption of shares. The exact output amount in the calldata is updated on chain to match the up to date debt
amount for the redemption of shares, which typically occurs due to borrow interest accrual and price changes
between off chain and on chain execution*


```solidity
function redeemWithVelora(
    ILeverageToken token,
    uint256 shares,
    uint256 minCollateralForSender,
    IVeloraAdapter veloraAdapter,
    address augustus,
    IVeloraAdapter.Offsets calldata offsets,
    bytes calldata swapData
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to redeem from|
|`shares`|`uint256`|Amount of shares to redeem|
|`minCollateralForSender`|`uint256`|Minimum amount of collateral for the sender to receive|
|`veloraAdapter`|`IVeloraAdapter`|Velora adapter to use for the swap|
|`augustus`|`address`|Velora Augustus address to use for the swap|
|`offsets`|`IVeloraAdapter.Offsets`|Offsets to use for updating the Velora Augustus calldata|
|`swapData`|`bytes`|Velora swap calldata to use for the swap|


## Errors
### CollateralSlippageTooHigh
Error thrown when the remaining collateral is less than the minimum collateral for the sender to receive


```solidity
error CollateralSlippageTooHigh(uint256 remainingCollateral, uint256 minCollateralForSender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`remainingCollateral`|`uint256`|The remaining collateral after the swap|
|`minCollateralForSender`|`uint256`|The minimum collateral for the sender to receive|

### InsufficientCollateralForDeposit
Error thrown when the collateral from the swap + the collateral from the sender is less than the collateral required for the deposit


```solidity
error InsufficientCollateralForDeposit(uint256 available, uint256 required);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`available`|`uint256`|The collateral from the swap + the collateral from the sender, available for the deposit|
|`required`|`uint256`|The collateral required for the deposit|

### MaxSwapCostExceeded
Error thrown when the cost of a swap exceeds the maximum allowed cost


```solidity
error MaxSwapCostExceeded(uint256 actualCost, uint256 maxCost);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actualCost`|`uint256`|The actual cost of the swap|
|`maxCost`|`uint256`|The maximum allowed cost of the swap|

### Unauthorized
Error thrown when the caller is not authorized to execute a function


```solidity
error Unauthorized();
```

## Structs
### Call
Struct containing the target, value, and data for a single external call.


```solidity
struct Call {
    address target;
    uint256 value;
    bytes data;
}
```

### DepositParams
Deposit related parameters to pass to the Morpho flash loan callback handler for deposits


```solidity
struct DepositParams {
    address sender;
    ILeverageToken leverageToken;
    uint256 collateralFromSender;
    uint256 minShares;
    Call[] swapCalls;
}
```

### MorphoCallbackData
Morpho flash loan callback data to pass to the Morpho flash loan callback handler


```solidity
struct MorphoCallbackData {
    LeverageRouterAction action;
    bytes data;
}
```

### RedeemParams
Redeem related parameters to pass to the Morpho flash loan callback handler for redeems


```solidity
struct RedeemParams {
    address sender;
    ILeverageToken leverageToken;
    uint256 shares;
    uint256 minCollateralForSender;
    Call[] swapCalls;
}
```

### RedeemWithVeloraParams
Redeem related parameters to pass to the Morpho flash loan callback handler for redeems using Velora


```solidity
struct RedeemWithVeloraParams {
    address sender;
    ILeverageToken leverageToken;
    uint256 shares;
    uint256 minCollateralForSender;
    IVeloraAdapter veloraAdapter;
    address augustus;
    IVeloraAdapter.Offsets offsets;
    bytes swapData;
}
```

## Enums
### LeverageRouterAction

```solidity
enum LeverageRouterAction {
    Deposit,
    Redeem,
    RedeemWithVelora
}
```

