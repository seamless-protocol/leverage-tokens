# IEtherFiL2ExchangeRateProvider
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/interfaces/periphery/IEtherFiL2ExchangeRateProvider.sol)


## Functions
### getConversionAmount

Get conversion amount for a token, given an amount in of token it should return the amount out. It also
applies the deposit fee. Will revert if: - No rate oracle is set for the token - The rate is outdated (fresh
period has passed)


```solidity
function getConversionAmount(address token, uint256 amount) external view returns (uint256 amountOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token to convert|
|`amount`|`uint256`|The amount of `token` to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|The amount of weETH received|


