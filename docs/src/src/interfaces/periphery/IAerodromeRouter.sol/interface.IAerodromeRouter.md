# IAerodromeRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/interfaces/periphery/IAerodromeRouter.sol)

Interface for the Aerodrome Router

*https://github.com/aerodrome-finance/contracts/blob/a5fae2e87e490d6b10f133e28cc11bcc58c5346a/contracts/interfaces/IRouter.sol*


## Functions
### swapExactTokensForTokens

Swap one token for another


```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|    Amount of token in|
|`amountOutMin`|`uint256`|Minimum amount of desired token received|
|`routes`|`Route[]`|      Array of trade routes used in the swap|
|`to`|`address`|          Recipient of the tokens received|
|`deadline`|`uint256`|    Deadline to receive tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|    Array of amounts returned per route|


### swapExactETHForTokens

Swap ETH for a token


```solidity
function swapExactETHForTokens(uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline)
    external
    payable
    returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountOutMin`|`uint256`|Minimum amount of desired token received|
|`routes`|`Route[]`|      Array of trade routes used in the swap|
|`to`|`address`|          Recipient of the tokens received|
|`deadline`|`uint256`|    Deadline to receive tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|    Array of amounts returned per route|


### swapExactTokensForETH

Swap a token for WETH (returned as ETH)


```solidity
function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|    Amount of token in|
|`amountOutMin`|`uint256`|Minimum amount of desired ETH|
|`routes`|`Route[]`|      Array of trade routes used in the swap|
|`to`|`address`|          Recipient of the tokens received|
|`deadline`|`uint256`|    Deadline to receive tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amounts`|`uint256[]`|    Array of amounts returned per route|


## Structs
### Route

```solidity
struct Route {
    address from;
    address to;
    bool stable;
    address factory;
}
```

