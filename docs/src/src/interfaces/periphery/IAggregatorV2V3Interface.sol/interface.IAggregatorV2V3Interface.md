# IAggregatorV2V3Interface
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/63ad4618d949dfaeb75f5b0c721e0d9d828264c2/src/interfaces/periphery/IAggregatorV2V3Interface.sol)

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

