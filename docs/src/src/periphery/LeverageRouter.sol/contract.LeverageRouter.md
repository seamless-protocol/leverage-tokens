# LeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/63ad4618d949dfaeb75f5b0c721e0d9d828264c2/src/periphery/LeverageRouter.sol)

**Inherits:**
[ILeverageRouter](/src/interfaces/periphery/ILeverageRouter.sol/interface.ILeverageRouter.md)

*The LeverageRouter contract is an immutable periphery contract that facilitates the use of flash loans and a swaps
to deposit and redeem equity from LeverageTokens.
The high-level deposit flow is as follows:
1. The sender calls `deposit` with the amount of collateral from the sender to deposit, the amount of debt to flash loan
(which will be swapped to collateral), the minimum amount of shares to receive, and the calldata to execute for
the swap of the flash loaned debt to collateral
2. The LeverageRouter will flash loan the debt asset amount and execute the calldata to swap it to collateral
3. The LeverageRouter will use the collateral from the swapped debt and the collateral from the sender for the deposit
into the LeverageToken, receiving LeverageToken shares and debt in return
4. The LeverageRouter will use the debt received from the deposit to repay the flash loan
6. The LeverageRouter will transfer the LeverageToken shares and any surplus debt assets to the sender
The high-level redeem flow is the same as the deposit flow, but in reverse.*

**Note:**
contact: security@seamlessprotocol.com


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


## Functions
### constructor

Creates a new LeverageRouter


```solidity
constructor(ILeverageManager _leverageManager, IMorpho _morpho);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


### convertEquityToCollateral

Converts an amount of equity to an amount of collateral for a LeverageToken, based on the current
collateral ratio of the LeverageToken


```solidity
function convertEquityToCollateral(ILeverageToken token, uint256 equityInCollateralAsset)
    public
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


### previewDeposit

Previews the deposit function call for an amount of equity and returns all required data


```solidity
function previewDeposit(ILeverageToken token, uint256 collateralFromSender)
    external
    view
    returns (ActionData memory previewData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`collateralFromSender`|`uint256`|The amount of collateral from the sender to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`previewData`|`ActionData`|Preview data for deposit - collateral Total amount of collateral that will be added to the LeverageToken (including collateral from swapping flash loaned debt) - debt Amount of debt that will be borrowed - shares Amount of shares that will be minted - tokenFee Amount of shares that will be charged for the deposit that are given to the LeverageToken - treasuryFee Amount of shares that will be charged for the deposit that are given to the treasury|


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

Executes the deposit into a LeverageToken by flash loaning the debt asset, swapping it to collateral,
depositing into the LeverageToken with the sender's collateral, and using the resulting debt to repay the flash loan.
Any surplus debt assets after repaying the flash loan are given to the sender.


```solidity
function _depositAndRepayMorphoFlashLoan(DepositParams memory params, uint256 debtLoan) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`DepositParams`|Params for the deposit into a LeverageToken|
|`debtLoan`|`uint256`|Amount of debt asset flash loaned|


### _redeemAndRepayMorphoFlashLoan

Executes the redeem from a LeverageToken by flash loaning the debt asset, swapping the collateral asset
to the debt asset using arbitrary calldata, using the resulting debt to repay the flash loan, and transferring
the remaining collateral asset and debt assets to the sender


```solidity
function _redeemAndRepayMorphoFlashLoan(RedeemParams memory params, uint256 debtLoanAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`RedeemParams`|Params for the redeem from a LeverageToken, using arbitrary calldata for the swap|
|`debtLoanAmount`|`uint256`|Amount of debt asset flash loaned|


### _redeemWithVeloraAndRepayMorphoFlashLoan

Executes the redeem from a LeverageToken by flash loaning the debt asset, swapping the collateral asset
to the debt asset using Velora, using the resulting debt to repay the flash loan, and transferring the remaining
collateral asset to the sender


```solidity
function _redeemWithVeloraAndRepayMorphoFlashLoan(RedeemWithVeloraParams memory params, uint256 debtLoanAmount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`RedeemWithVeloraParams`|Params for the redeem from a LeverageToken using Velora|
|`debtLoanAmount`|`uint256`|Amount of debt asset flash loaned|


### receive


```solidity
receive() external payable;
```

