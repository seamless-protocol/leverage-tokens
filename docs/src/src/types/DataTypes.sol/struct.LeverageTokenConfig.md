# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e2065c10183acb51865104847d299ff5ad4684d2/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 depositTokenFee;
    uint256 withdrawTokenFee;
}
```

