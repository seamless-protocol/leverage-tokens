# PricingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/5f47bb45d300f9abc725e6a08e82ac80219f0e37/src/periphery/PricingAdapter.sol)

**Inherits:**
[IPricingAdapter](/src/interfaces/periphery/IPricingAdapter.sol/interface.IPricingAdapter.md)


## State Variables
### WAD

```solidity
uint256 internal constant WAD = 1e18;
```


### leverageManager
The LeverageManager contract


```solidity
ILeverageManager public immutable leverageManager;
```


## Functions
### constructor

Constructor


```solidity
constructor(ILeverageManager _leverageManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leverageManager`|`ILeverageManager`|The LeverageManager contract|


### getLeverageTokenPriceInCollateral

Returns the price of one LeverageToken (1e18 wei) denominated in collateral asset of the LeverageToken


```solidity
function getLeverageTokenPriceInCollateral(ILeverageToken leverageToken) public view returns (uint256);
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
function getLeverageTokenPriceInDebt(ILeverageToken leverageToken) public view returns (uint256);
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
) public view returns (int256);
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


