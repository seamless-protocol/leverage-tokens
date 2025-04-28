# IEtherFiL2ModeSyncPool
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/c66c8e188b984325bffdd199b88ca303e9f58b11/src/interfaces/periphery/IEtherFiL2ModeSyncPool.sol)


## Functions
### deposit

Deposits `tokenIn` into the EtherFi L2 Mode Sync Pool and returns `minAmountOut` of weETH


```solidity
function deposit(address tokenIn, uint256 amountIn, uint256 minAmountOut, address referral)
    external
    payable
    returns (uint256 amountOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenIn`|`address`|The address of the token to deposit. The token must be whitelisted|
|`amountIn`|`uint256`|The amount of `tokenIn` to deposit|
|`minAmountOut`|`uint256`|The minimum amount of weETH to receive|
|`referral`|`address`|The address of the referral|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|The amount of weETH received|


