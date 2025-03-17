# MorphoLendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/adapters/MorphoLendingAdapter.sol)

**Inherits:**
[IMorphoLendingAdapter](/src/interfaces/IMorphoLendingAdapter.sol/interface.IMorphoLendingAdapter.md), Initializable


## State Variables
### leverageManager
The Seamless ilm-v2 LeverageManager contract


```solidity
ILeverageManager public immutable leverageManager;
```


### morpho
The Morpho core protocol contract


```solidity
IMorpho public immutable morpho;
```


### morphoMarketId
The ID of the Morpho market that the lending adapter manages a position in


```solidity
Id public morphoMarketId;
```


### marketParams
The market parameters of the Morpho lending pool


```solidity
MarketParams public marketParams;
```


## Functions
### onlyLeverageManager

*Reverts if the caller is not the stored leverageManager address*


```solidity
modifier onlyLeverageManager();
```

### constructor

Creates a new Morpho lending adapter


```solidity
constructor(ILeverageManager _leverageManager, IMorpho _morpho);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The Seamless ilm-v2 LeverageManager contract|
|`_morpho`|`IMorpho`|The Morpho core protocol contract|


### initialize

Initializes the Morpho lending adapter


```solidity
function initialize(Id _morphoMarketId) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_morphoMarketId`|`Id`|The Morpho market ID|


### getCollateralAsset

Returns the address of the collateral asset


```solidity
function getCollateralAsset() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|collateralAsset Address of the collateral asset|


### getDebtAsset

Returns the address of the debt asset


```solidity
function getDebtAsset() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|debtAsset Address of the debt asset|


### convertCollateralToDebtAsset

Converts amount of collateral asset to debt asset amount based on lending pool oracle


```solidity
function convertCollateralToDebtAsset(uint256 collateral) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Collateral amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|debt Amount of debt asset|


### convertDebtToCollateralAsset

Converts amount of debt asset to collateral asset amount based on lending pool oracle


```solidity
function convertDebtToCollateralAsset(uint256 debt) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Debt amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|collateral Amount of collateral asset|


### getCollateral

Returns total collateral of the position held by the lending adapter


```solidity
function getCollateral() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|collateral Total collateral of the position held by the lending adapter|


### getCollateralInDebtAsset

Returns total collateral of the position held by the lending adapter denominated in debt asset


```solidity
function getCollateralInDebtAsset() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|collateral Total collateral of the position held by the lending adapter denominated in debt asset|


### getDebt

Returns total debt of the position held by the lending adapter


```solidity
function getDebt() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|debt Total debt of the position held by the lending adapter|


### getEquityInCollateralAsset

Returns total equity of the position held by the lending adapter denominated in collateral asset


```solidity
function getEquityInCollateralAsset() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|equity Equity of the position held by the lending adapter|


### getEquityInDebtAsset

Returns total equity of the position held by the lending adapter denominated in debt asset

*Equity is calculated as collateral - debt*


```solidity
function getEquityInDebtAsset() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|equity Equity of the position held by the lending adapter|


### addCollateral

Supplies collateral assets to the lending pool


```solidity
function addCollateral(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to supply|


### removeCollateral

Withdraws collateral assets from the lending pool


```solidity
function removeCollateral(uint256 amount) external onlyLeverageManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to withdraw|


### borrow

Borrows assets from the lending pool


```solidity
function borrow(uint256 amount) external onlyLeverageManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to borrow|


### repay

Repays debt to the lending pool


```solidity
function repay(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets of debt to repay|


