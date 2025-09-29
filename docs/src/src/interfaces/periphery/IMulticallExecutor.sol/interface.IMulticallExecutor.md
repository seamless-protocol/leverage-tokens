# IMulticallExecutor
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/interfaces/periphery/IMulticallExecutor.sol)


## Functions
### multicallAndSweep

Executes a multicall and sweeps tokens afterwards


```solidity
function multicallAndSweep(Call[] calldata calls, IERC20[] calldata tokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`calls`|`Call[]`|The calls to execute|
|`tokens`|`IERC20[]`|The tokens to sweep to the sender after executing the calls. To sweep ETH, include address(0).|


## Structs
### Call
Struct containing the target, value, and data for a single external call.


```solidity
struct Call {
    address target;
    uint256 value;
    bytes data;
}
```

