# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/e940fa5a38a4ecdb2ab814caac34ad52528360be/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 depositTokenFee;
    uint256 withdrawTokenFee;
}
```

