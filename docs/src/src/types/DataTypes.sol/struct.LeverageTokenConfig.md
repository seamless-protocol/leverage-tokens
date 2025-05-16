# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6c745a1fb2c5cc77df7fd3106f57db1adc947b75/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

