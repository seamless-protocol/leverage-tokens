# PricingAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/2b21c8087d500fe0ba2ccbc6534d0a70d879e057/src/periphery/PricingAdapter.sol)

**Inherits:**
[IPricingAdapter](/src/interfaces/periphery/IPricingAdapter.sol/interface.IPricingAdapter.md)

*This contract is used to get the price of a LeverageToken in the collateral asset of the LeverageToken, debt asset
of the LeverageToken, or the price using a Chainlink oracle.
The decimal precision of the price using a Chainlink oracle is equal to the decimals of the base asset of the Chainlink
oracle.
Integrators using this PricingAdapter should carefully evaluate and understand the risks of using this contract before
using it. Some points to consider are the rounding direction and precision used by the logic in this contract.*

**Note:**
contact: security@seamlessprotocol.com


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
|`<none>`|`int256`|price The price of one LeverageToken adjusted to the price on the Chainlink oracle, with decimal precision equal to the base asset decimals|


