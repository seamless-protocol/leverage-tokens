# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/ca7af3bd8afb6a515c334e2f448f621a379dc94e/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

