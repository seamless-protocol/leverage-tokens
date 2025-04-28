# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/c66c8e188b984325bffdd199b88ca303e9f58b11/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

