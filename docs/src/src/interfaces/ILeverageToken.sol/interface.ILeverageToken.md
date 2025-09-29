# ILeverageToken
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/interfaces/ILeverageToken.sol)

**Inherits:**
IERC20


## Functions
### convertToAssets

Converts an amount of LeverageToken shares to an amount of equity in collateral asset, based on the
price oracle used by the underlying lending adapter and state of the LeverageToken.

Equity in collateral asset is equal to the difference between collateral and debt denominated
in the collateral asset.


```solidity
function convertToAssets(uint256 shares) external view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares to convert to equity in collateral asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of equity in collateral asset that correspond to the shares|


### convertToShares

Converts an amount of equity in collateral asset to an amount of LeverageToken shares, based on the
price oracle used by the underlying lending adapter and state of the LeverageToken.

Equity in collateral asset is equal to the difference between collateral and debt denominated
in the collateral asset.


```solidity
function convertToShares(uint256 assets) external view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of equity in collateral asset to convert to shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares that correspond to the equity in collateral asset|


### mint

Mints new tokens to the specified address

*Only the owner can call this function. Owner should be the LeverageManager contract*


```solidity
function mint(address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to mint tokens to|
|`amount`|`uint256`|The amount of tokens to mint|


### burn

Burns tokens from the specified address

*Only the owner can call this function. Owner should be the LeverageManager contract*


```solidity
function burn(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to burn tokens from|
|`amount`|`uint256`|The amount of tokens to burn|


## Events
### LeverageTokenInitialized
Event emitted when the leverage token is initialized


```solidity
event LeverageTokenInitialized(string name, string symbol);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of the LeverageToken|
|`symbol`|`string`|The symbol of the LeverageToken|

