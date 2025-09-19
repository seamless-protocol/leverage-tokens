# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/d05e32eba516aef697eb220f9b66720e48434416/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

