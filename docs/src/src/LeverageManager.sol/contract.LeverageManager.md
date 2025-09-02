# LeverageManager
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/5f47bb45d300f9abc725e6a08e82ac80219f0e37/src/LeverageManager.sol)

**Inherits:**
[ILeverageManager](/src/interfaces/ILeverageManager.sol/interface.ILeverageManager.md), AccessControlUpgradeable, ReentrancyGuardTransientUpgradeable, [FeeManager](/src/FeeManager.sol/abstract.FeeManager.md), UUPSUpgradeable

*The LeverageManager contract is an upgradeable core contract that is responsible for managing the creation of LeverageTokens.
It also acts as an entry point for users to mint and redeem LeverageTokens (shares), and for
rebalancers to rebalance LeverageTokens.
LeverageTokens are ERC20 tokens that are akin to shares in an ERC-4626 vault - they represent a claim on the equity held by
the LeverageToken. They can be created on this contract by calling `createNewLeverageToken`, and their configuration on the
LeverageManager is immutable.
Note: Although the LeverageToken configuration saved on the LeverageManager is immutable, the configured LendingAdapter and
RebalanceAdapter for the LeverageToken may be upgradeable contracts.
The LeverageManager also inherits the `FeeManager` contract, which is used to manage LeverageToken fees (which accrue to
the share value of the LeverageToken) and the treasury fees.
For mints of LeverageTokens (shares), the collateral and debt required is calculated by using the LeverageToken's
current collateral ratio. As such, the collateral ratio after a mint must be equal to the collateral ratio before a
mint, within some rounding error.
[CAUTION]
====
- LeverageTokens are susceptible to inflation attacks like ERC-4626 vaults:
"In empty (or nearly empty) ERC-4626 vaults, mints are at high risk of being stolen through frontrunning
with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
mint of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Redeems may
similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
verifying the amount received is as expected, using a wrapper that performs these checks such as
https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router]."
As such it is highly recommended that LeverageToken creators make an initial mint of a non-trivial amount of equity.
It is also recommended to use a router that performs slippage checks when minting and redeeming.
- LeverageToken creation is permissionless and can be configured with arbitrary lending adapters, rebalance adapters, and
underlying collateral and debt assets. As such, the adapters and tokens used by a LeverageToken are part of the risk
profile of the LeverageToken, and should be carefully considered by users before using a LeverageToken.
- LeverageTokens can be configured with arbitrary lending adapters, thus LeverageTokens are directly affected by the
specific mechanisms of the underlying lending market that their lending adapter integrates with. As mentioned above,
it is highly recommended that users research and understand the lending adapter used by the LeverageToken they are
considering using. Some examples:
- Morpho: Users should be aware that Morpho market creation is permissionless, and that the price oracle used by
by the market may be manipulatable.
- Aave v3: Allows rehypothecation of collateral, which may lead to reverts when trying to remove collateral from the
market during redeems and rebalances.*


## State Variables
### BASE_RATIO

```solidity
uint256 public constant BASE_RATIO = 1e18;
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
function initialize(address initialAdmin, address treasury, IBeaconProxyFactory leverageTokenFactory)
    external
    initializer;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

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
    public
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

*Initial collateral ratio is followed when the LeverageToken has no shares and on mints when debt is 0.*


```solidity
function getLeverageTokenInitialCollateralRatio(ILeverageToken token) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to get initial collateral ratio for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|initialCollateralRatio Initial collateral ratio for the LeverageToken|


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
function createNewLeverageToken(LeverageTokenConfig calldata tokenConfig, string memory name, string memory symbol)
    external
    nonReentrant
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

*Sender should approve leverage manager to spend collateral amount of collateral asset*


```solidity
function previewDeposit(ILeverageToken token, uint256 collateral) public view returns (ActionData memory);
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
function previewMint(ILeverageToken token, uint256 shares) public view returns (ActionData memory);
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
function previewRedeem(ILeverageToken token, uint256 shares) public view returns (ActionData memory);
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
function previewWithdraw(ILeverageToken token, uint256 collateral) public view returns (ActionData memory);
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


### deposit

Deposits collateral into a LeverageToken and mints shares to the sender

*Sender should approve leverage manager to spend collateral amount of collateral asset*


```solidity
function deposit(ILeverageToken token, uint256 collateral, uint256 minShares)
    external
    nonReentrant
    returns (ActionData memory actionData);
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
|`actionData`|`ActionData`|depositData Action data for the deposit - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - shares Amount of shares minted to the sender - tokenFee Amount of shares that was charged for the deposit that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the deposit that are given to the treasury|


### mint

Mints shares of a LeverageToken to the sender

*Sender should approve leverage manager to spend collateral amount of collateral asset, which can be
previewed with previewMint*


```solidity
function mint(ILeverageToken token, uint256 shares, uint256 maxCollateral)
    external
    nonReentrant
    returns (ActionData memory actionData);
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
|`actionData`|`ActionData`|mintData Action data for the mint - collateral Amount of collateral that was added, including any fees - debt Amount of debt that was added - shares Amount of shares minted to the sender - tokenFee Amount of shares that was charged for the mint that are given to the LeverageToken - treasuryFee Amount of shares that was charged for the mint that are given to the treasury|


### rebalance

Rebalances a LeverageToken based on provided actions

*Anyone can call this function. At the end function will just check if the affected LeverageToken is in a
better state than before rebalance. Caller needs to calculate and to provide tokens for rebalancing and he needs
to specify tokens that he wants to receive*


```solidity
function rebalance(
    ILeverageToken leverageToken,
    RebalanceAction[] calldata actions,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 amountIn,
    uint256 amountOut
) external nonReentrant;
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


### redeem

Redeems equity from a LeverageToken and burns shares from sender


```solidity
function redeem(ILeverageToken token, uint256 shares, uint256 minCollateral)
    external
    nonReentrant
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


### withdraw

Withdraws collateral from a LeverageToken and burns shares from sender


```solidity
function withdraw(ILeverageToken token, uint256 collateral, uint256 maxShares)
    external
    nonReentrant
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


### _convertCollateralToDebt

Converts collateral to debt given the state of the LeverageToken


```solidity
function _convertCollateralToDebt(
    ILeverageToken token,
    ILendingAdapter lendingAdapter,
    uint256 collateral,
    uint256 totalCollateral,
    uint256 totalDebt,
    Math.Rounding rounding
) internal view returns (uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert collateral for|
|`lendingAdapter`|`ILendingAdapter`|Lending adapter of the LeverageToken|
|`collateral`|`uint256`|Collateral to convert to debt|
|`totalCollateral`|`uint256`|Total collateral of the LeverageToken|
|`totalDebt`|`uint256`|Total debt of the LeverageToken|
|`rounding`|`Math.Rounding`|Rounding mode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Debt|


### _convertCollateralToShares

Converts collateral to shares given the state of the LeverageToken


```solidity
function _convertCollateralToShares(
    ILeverageToken token,
    ILendingAdapter lendingAdapter,
    uint256 collateral,
    uint256 totalSupply,
    Math.Rounding rounding
) internal view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert collateral for|
|`lendingAdapter`|`ILendingAdapter`|Lending adapter of the LeverageToken|
|`collateral`|`uint256`|Collateral to convert to shares|
|`totalSupply`|`uint256`|Total supply of shares of the LeverageToken|
|`rounding`|`Math.Rounding`|Rounding mode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Shares|


### _convertSharesToCollateral

Converts shares to collateral given the state of the LeverageToken


```solidity
function _convertSharesToCollateral(
    ILeverageToken token,
    ILendingAdapter lendingAdapter,
    uint256 shares,
    uint256 totalCollateral,
    uint256 totalSupply,
    Math.Rounding rounding
) internal view returns (uint256 collateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert shares for|
|`lendingAdapter`|`ILendingAdapter`|Lending adapter of the LeverageToken|
|`shares`|`uint256`|Shares to convert to collateral|
|`totalCollateral`|`uint256`|Total collateral of the LeverageToken|
|`totalSupply`|`uint256`|Total supply of shares of the LeverageToken|
|`rounding`|`Math.Rounding`|Rounding mode|


### _convertSharesToDebt

Converts shares to debt given the state of the LeverageToken


```solidity
function _convertSharesToDebt(
    ILeverageToken token,
    ILendingAdapter lendingAdapter,
    uint256 shares,
    uint256 totalDebt,
    uint256 totalSupply,
    Math.Rounding rounding
) internal view returns (uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to convert shares for|
|`lendingAdapter`|`ILendingAdapter`|Lending adapter of the LeverageToken|
|`shares`|`uint256`|Shares to convert to debt|
|`totalDebt`|`uint256`|Total debt of the LeverageToken|
|`totalSupply`|`uint256`|Total supply of shares of the LeverageToken|
|`rounding`|`Math.Rounding`|Rounding mode|


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


### _getLeverageTokenState


```solidity
function _getLeverageTokenState(ILendingAdapter lendingAdapter)
    internal
    view
    returns (LeverageTokenState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lendingAdapter`|`ILendingAdapter`|LendingAdapter of the LeverageToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LeverageTokenState`|LeverageToken state|


### _mint

Helper function for executing a mint action on a LeverageToken


```solidity
function _mint(ILeverageToken token, ActionData memory mintData) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to mint shares for|
|`mintData`|`ActionData`|Action data for the mint|


### _redeem

Helper function for executing a redeem action on a LeverageToken


```solidity
function _redeem(ILeverageToken token, ActionData memory redeemData) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to redeem shares for|
|`redeemData`|`ActionData`|Action data for the redeem|


### _transferTokens

Helper function for transferring tokens, or no-op if token is 0 address

*If from address is this smart contract it will use the regular transfer function otherwise it will use transferFrom*


```solidity
function _transferTokens(IERC20 token, address from, address to, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|Token to transfer|
|`from`|`address`|Address to transfer tokens from|
|`to`|`address`|Address to transfer tokens to|
|`amount`|`uint256`||


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

