# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/5f47bb45d300f9abc725e6a08e82ac80219f0e37/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

