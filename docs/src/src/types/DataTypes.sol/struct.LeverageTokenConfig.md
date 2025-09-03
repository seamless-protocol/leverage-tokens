# LeverageTokenConfig
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6fd46c53a22afa8918e99c47589c9bd10722b593/src/types/DataTypes.sol)

*Struct that contains the entire LeverageToken config*


```solidity
struct LeverageTokenConfig {
    ILendingAdapter lendingAdapter;
    IRebalanceAdapterBase rebalanceAdapter;
    uint256 mintTokenFee;
    uint256 redeemTokenFee;
}
```

