# LeverageToken
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/40214436ae3956021858cb95e6ff881f6ede8e11/src/LeverageToken.sol)

**Inherits:**
Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, [ILeverageToken](/src/interfaces/ILeverageToken.sol/interface.ILeverageToken.md)

*The LeverageToken contract is an upgradeable ERC20 token that represents a claim to the equity held by the LeverageToken.
It is used to represent a user's claim to the equity held by the LeverageToken in the LeverageManager.*


## Functions
### initialize


```solidity
function initialize(address _owner, string memory _name, string memory _symbol) external initializer;
```

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


