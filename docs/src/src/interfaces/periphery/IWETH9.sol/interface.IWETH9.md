# IWETH9
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/ca7af3bd8afb6a515c334e2f448f621a379dc94e/src/interfaces/periphery/IWETH9.sol)


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


