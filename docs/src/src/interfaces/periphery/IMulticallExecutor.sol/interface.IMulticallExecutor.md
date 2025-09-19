# IMulticallExecutor
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/d05e32eba516aef697eb220f9b66720e48434416/src/interfaces/periphery/IMulticallExecutor.sol)


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
|`tokens`|`IERC20[]`|The tokens to sweep to the sender after executing the calls. ETH is always swept to the sender.|


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

