# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/63ad4618d949dfaeb75f5b0c721e0d9d828264c2/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

