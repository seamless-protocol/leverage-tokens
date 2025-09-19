# LeverageToken
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/d05e32eba516aef697eb220f9b66720e48434416/src/LeverageToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, [ILeverageToken](/src/interfaces/ILeverageToken.sol/interface.ILeverageToken.md)

*The LeverageToken contract is an upgradeable ERC20 token that represents a claim to the equity held by the LeverageToken.
It is used to represent a user's claim to the equity held by the LeverageToken in the LeverageManager.*

**Note:**
contact: security@seamlessprotocol.com


## Functions
### initialize


```solidity
function initialize(address _leverageManager, string memory _name, string memory _symbol) external initializer;
```

### convertToAssets

Converts an amount of LeverageToken shares to an amount of equity in collateral asset, based on the
price oracle used by the underlying lending adapter and state of the LeverageToken.


```solidity
function convertToAssets(uint256 shares) public view returns (uint256 assets);
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


```solidity
function convertToShares(uint256 assets) public view returns (uint256 shares);
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
function mint(address to, uint256 amount) external onlyOwner;
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
function burn(address from, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to burn tokens from|
|`amount`|`uint256`|The amount of tokens to burn|


