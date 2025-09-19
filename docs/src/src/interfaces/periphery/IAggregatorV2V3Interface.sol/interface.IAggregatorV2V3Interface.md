# IAggregatorV2V3Interface
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/d05e32eba516aef697eb220f9b66720e48434416/src/interfaces/periphery/IAggregatorV2V3Interface.sol)

Interface for Chainlink Aggregator


## Functions
### decimals


```solidity
function decimals() external view returns (uint8);
```

### latestAnswer


```solidity
function latestAnswer() external view returns (int256);
```

### latestRoundData


```solidity
function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
```

