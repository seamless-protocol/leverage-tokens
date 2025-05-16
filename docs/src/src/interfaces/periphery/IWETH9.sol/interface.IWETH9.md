# IWETH9
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6c745a1fb2c5cc77df7fd3106f57db1adc947b75/src/interfaces/periphery/IWETH9.sol)


## Functions
### deposit

Deposit ether to get wrapped ether


```solidity
function deposit() external payable;
```

### withdraw

Withdraw wrapped ether to get ether


```solidity
function withdraw(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of wrapped ether to withdraw|


