# IPricingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/6fd46c53a22afa8918e99c47589c9bd10722b593/src/interfaces/periphery/IPricingAdapter.sol)


## Functions
### leverageManager

The LeverageManager contract


```solidity
function leverageManager() external view returns (ILeverageManager _leverageManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|


### getLeverageTokenPriceInCollateral

Returns the price of one LeverageToken (1e18 wei) denominated in collateral asset of the LeverageToken


```solidity
function getLeverageTokenPriceInCollateral(ILeverageToken leverageToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken to get the price for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price The price of one LeverageToken denominated in collateral asset|


### getLeverageTokenPriceInDebt

Returns the price of one LeverageToken (1e18 wei) denominated in debt asset of the LeverageToken


```solidity
function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken to get the price for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price The price of one LeverageToken denominated in debt asset|


### getLeverageTokenPriceAdjusted

Returns the price of one LeverageToken (1e18 wei) adjusted to the price on the Chainlink oracle


```solidity
function getLeverageTokenPriceAdjusted(
    ILeverageToken leverageToken,
    IAggregatorV2V3Interface chainlinkOracle,
    bool isBaseDebtAsset
) external view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`leverageToken`|`ILeverageToken`|The LeverageToken to get the price for|
|`chainlinkOracle`|`IAggregatorV2V3Interface`|The Chainlink oracle to use for pricing|
|`isBaseDebtAsset`|`bool`|True if the debt asset is the base asset of the Chainlink oracle, false if the collateral asset is the base asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|price The price of one LeverageToken adjusted to the price on the Chainlink oracle, in the decimals of the oracle|


