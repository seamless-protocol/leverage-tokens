# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/40214436ae3956021858cb95e6ff881f6ede8e11/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

