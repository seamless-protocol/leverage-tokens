# ILendingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/ILendingAdapter.sol)


## Functions
### getCollateralAsset

Returns the address of the collateral asset


```solidity
function getCollateralAsset() external view returns (IERC20 collateralAsset);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateralAsset`|`IERC20`|Address of the collateral asset|


### getDebtAsset

Returns the address of the debt asset


```solidity
function getDebtAsset() external view returns (IERC20 debtAsset);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debtAsset`|`IERC20`|Address of the debt asset|


### convertCollateralToDebtAsset

Converts amount of collateral asset to debt asset amount based on lending pool oracle


```solidity
function convertCollateralToDebtAsset(uint256 collateral) external view returns (uint256 debt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Collateral amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Amount of debt asset|


### convertDebtToCollateralAsset

Converts amount of debt asset to collateral asset amount based on lending pool oracle


```solidity
function convertDebtToCollateralAsset(uint256 debt) external view returns (uint256 collateral);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Debt amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Amount of collateral asset|


### getCollateral

Returns total collateral of the position held by the lending adapter


```solidity
function getCollateral() external view returns (uint256 collateral);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Total collateral of the position held by the lending adapter|


### getCollateralInDebtAsset

Returns total collateral of the position held by the lending adapter denominated in debt asset


```solidity
function getCollateralInDebtAsset() external view returns (uint256 collateral);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collateral`|`uint256`|Total collateral of the position held by the lending adapter denominated in debt asset|


### getDebt

Returns total debt of the position held by the lending adapter


```solidity
function getDebt() external view returns (uint256 debt);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`debt`|`uint256`|Total debt of the position held by the lending adapter|


### getEquityInCollateralAsset

Returns total equity of the position held by the lending adapter denominated in collateral asset


```solidity
function getEquityInCollateralAsset() external view returns (uint256 equity);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`equity`|`uint256`|Equity of the position held by the lending adapter|


### getEquityInDebtAsset

Returns total equity of the position held by the lending adapter denominated in debt asset

*Equity is calculated as collateral - debt*


```solidity
function getEquityInDebtAsset() external view returns (uint256 equity);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`equity`|`uint256`|Equity of the position held by the lending adapter|


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
function removeCollateral(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to withdraw|


### borrow

Borrows assets from the lending pool


```solidity
function borrow(uint256 amount) external;
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


## Errors
### Unauthorized
Error thrown when the caller is unauthorized to call a function


```solidity
error Unauthorized();
```

