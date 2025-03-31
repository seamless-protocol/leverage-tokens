# LeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e2065c10183acb51865104847d299ff5ad4684d2/src/LeverageManager.sol)

**Inherits:**
[ILeverageManager](/src/interfaces/ILeverageManager.sol/interface.ILeverageManager.md), AccessControlUpgradeable, [FeeManager](/src/FeeManager.sol/contract.FeeManager.md), UUPSUpgradeable

*The LeverageManager contract is an upgradeable core contract that is responsible for managing the creation of LeverageTokens.
It also acts as an entry point for users to deposit and withdraw equity from the position held by the LeverageToken, and for
rebalancers to rebalance LeverageTokens.
LeverageTokens are ERC20 tokens that are akin to shares in an ERC-4626 vault - they represent a claim on the equity held by
the LeverageToken. They can be created on this contract by calling `createNewLeverageToken`, and their configuration on the
LeverageManager is immutable.
Note: Although the LeverageToken configuration saved on the LeverageManager is immutable, the configured LendingAdapter and
RebalanceAdapter for the LeverageToken may be upgradeable contracts.
The LeverageManager also inherits the `FeeManager` contract, which is used to manage LeverageToken fees (which accrue to
the share value of the LeverageToken) and the treasury fees.
For deposits of equity into a LeverageToken, the collateral and debt required is calculated by using the LeverageToken's
current collateral ratio. As such, the collateral ratio after a deposit must be equal to the collateral ratio before a
deposit, within some rounding error.
[CAUTION]
====
LeverageTokens are susceptible to inflation attacks like ERC-4626 vaults:
"In empty (or nearly empty) ERC-4626 vaults, deposits are at high risk of being stolen through frontrunning
with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Withdrawals may
similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
verifying the amount received is as expected, using a wrapper that performs these checks such as
https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router]."
As such it is highly recommended that LeverageToken creators make an initial deposit of a non-trivial amount of equity.
It is also recommended to use a router that performs slippage checks when depositing and withdrawing.*


## State Variables
### BASE_RATIO

```solidity
uint256 public constant BASE_RATIO = 1e18;
```


### DECIMALS_OFFSET

```solidity
uint256 public constant DECIMALS_OFFSET = 0;
```


### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


## Functions
### _getLeverageManagerStorage


```solidity
function _getLeverageManagerStorage() internal pure returns (LeverageManagerStorage storage $);
```

### initialize


```solidity
function initialize(address initialAdmin, IBeaconProxyFactory leverageTokenFactory) external initializer;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### getLeverageTokenFactory

Returns the factory for creating new LeverageTokens


```solidity
function getLeverageTokenFactory() public view returns (IBeaconProxyFactory factory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`factory`|`IBeaconProxyFactory`|Factory for creating new LeverageTokens|


### getLeverageTokenCollateralAsset

Returns the collateral asset for a LeverageToken


```solidity
function getLeverageTokenCollateralAsset(ILeverageToken token) public view returns (IERC20 collateralAsset);
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
function getLeverageTokenDebtAsset(ILeverageToken token) public view returns (IERC20 debtAsset);
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
function getLeverageTokenRebalanceAdapter(ILeverageToken token) public view returns (IRebalanceAdapterBase module);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get the rebalance adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`module`|`IRebalanceAdapterBase`|adapter Rebalance adapter for the LeverageToken|


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


### getLeverageTokenLendingAdapter

Returns the lending adapter for a LeverageToken


```solidity
function getLeverageTokenLendingAdapter(ILeverageToken token) public view returns (ILendingAdapter adapter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get lending adapter for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`ILendingAdapter`|Lending adapter for the LeverageToken|


### getLeverageTokenInitialCollateralRatio

Returns the initial collateral ratio for a LeverageToken

*Initial collateral ratio is followed when the LeverageToken has no shares and on deposits when debt is 0.*


```solidity
function getLeverageTokenInitialCollateralRatio(ILeverageToken token) public view returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get initial collateral ratio for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|initialCollateralRatio Initial collateral ratio for the LeverageToken|


### getLeverageTokenState

Returns all data required to describe current LeverageToken state - collateral, debt, equity and collateral ratio


```solidity
function getLeverageTokenState(ILeverageToken token) public view returns (LeverageTokenState memory state);
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
function createNewLeverageToken(LeverageTokenConfig calldata tokenConfig, string memory name, string memory symbol)
    external
    returns (ILeverageToken token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenConfig`|`LeverageTokenConfig`||
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
    public
    view
    returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Equity to deposit denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for deposit - collateralToAdd Amount of collateral that sender needs to approve the LeverageManager to spend, this includes any fees - debtToBorrow Amount of debt that will be borrowed and sent to sender - equity Amount of equity that will be deposited before fees, denominated in collateral asset - shares Amount of shares that will be minted to the sender - tokenFee Amount of collateral asset that will be charged for the deposit to the leverage token - treasuryFee Amount of collateral asset that will be charged for the deposit to the treasury|


### previewWithdraw

Previews withdraw function call and returns all required data

*Sender should approve leverage manager to spend debtToRepay amount of debt asset*


```solidity
function previewWithdraw(ILeverageToken token, uint256 equityInCollateralAsset)
    public
    view
    returns (ActionData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview withdraw for|
|`equityInCollateralAsset`|`uint256`|Equity to withdraw denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ActionData`|previewData Preview data for withdraw - collateralToRemove Amount of collateral that will be removed from the LeverageToken and sent to the sender - debtToRepay Amount of debt that will be taken from sender and repaid to the LeverageToken - equity Amount of equity that will be withdrawn before fees, denominated in collateral asset - shares Amount of shares that will be burned from sender - tokenFee Amount of collateral asset that will be charged for the withdraw to the leverage token - treasuryFee Amount of collateral asset that will be charged for the withdraw to the treasury|


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


### _convertToShares

Function that converts user's equity to shares

Function uses OZ formula for calculating shares

*Function should be used to calculate how much shares user should receive for their equity*


```solidity
function _convertToShares(ILeverageToken token, uint256 equityInCollateralAsset)
    internal
    view
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert equity for|
|`equityInCollateralAsset`|`uint256`|Equity to convert to shares, denominated in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Shares|


### _previewAction

Previews parameters related to a deposit action

*If the LeverageToken has zero total supply of shares (so the LeverageToken does not hold any collateral or debt,
or holds some leftover dust after all shares are redeemed), then the preview will use the target
collateral ratio for determining how much collateral and debt is required instead of the current collateral ratio.*

*If action is deposit collateral will be rounded down and debt up, if action is withdraw collateral will be rounded up and debt down*


```solidity
function _previewAction(ILeverageToken token, uint256 equityInCollateralAsset, ExternalAction action)
    internal
    view
    returns (ActionData memory data);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to preview deposit for|
|`equityInCollateralAsset`|`uint256`|Amount of equity to add or withdraw, denominated in collateral asset|
|`action`|`ExternalAction`|Type of the action to preview, can be Deposit or Withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`data`|`ActionData`|Preview data for the action|


### _computeCollateralAndDebtForAction

Function that computes collateral and debt required by the position held by a LeverageToken for a given action and an amount of equity to add / remove


```solidity
function _computeCollateralAndDebtForAction(
    ILeverageToken token,
    uint256 equityInCollateralAsset,
    ExternalAction action
) internal view returns (uint256 collateral, uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to compute collateral and debt for|
|`equityInCollateralAsset`|`uint256`|Equity amount in collateral asset|
|`action`|`ExternalAction`|Action to compute collateral and debt for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Collateral to add / remove from the LeverageToken|
|`debt`|`uint256`|Debt to borrow / repay to the LeverageToken|


### _isElementInSlice

Helper function that checks if a specific element has already been processed in the slice up to the given index

*This function is used to check if we already stored the state of the LeverageToken before rebalance.
This function is used to check if LeverageToken state has been already validated after rebalance*


```solidity
function _isElementInSlice(RebalanceAction[] calldata actions, ILeverageToken token, uint256 untilIndex)
    internal
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actions`|`RebalanceAction[]`|Entire array to go through|
|`token`|`ILeverageToken`|Element to search for|
|`untilIndex`|`uint256`|Search until this specific index|


### _executeLendingAdapterAction

Executes actions on the LendingAdapter for a specific LeverageToken


```solidity
function _executeLendingAdapterAction(ILeverageToken token, ActionType actionType, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to execute action for|
|`actionType`|`ActionType`|Type of the action to execute|
|`amount`|`uint256`|Amount to execute action with|


### _transferTokens

Used for batching token transfers

*If from address is this smart contract it will use the regular transfer function otherwise it will use transferFrom*


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
    IBeaconProxyFactory tokenFactory;
    mapping(ILeverageToken token => BaseLeverageTokenConfig) config;
}
```

