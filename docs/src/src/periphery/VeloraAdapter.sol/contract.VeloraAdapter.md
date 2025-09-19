# VeloraAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/d05e32eba516aef697eb220f9b66720e48434416/src/periphery/VeloraAdapter.sol)

**Inherits:**
[IVeloraAdapter](/src/interfaces/periphery/IVeloraAdapter.sol/interface.IVeloraAdapter.md)

Adapter for trading with Velora.

*This adapter was modified from the original version implemented by Morpho
https://github.com/morpho-org/bundler3/blob/4887f33299ba6e60b54a51237b16e7392dceeb97/src/adapters/ParaswapAdapter.sol*

**Note:**
contact: security@seamlessprotocol.com


## State Variables
### AUGUSTUS_REGISTRY
The address of the Augustus registry.


```solidity
IAugustusRegistry public immutable AUGUSTUS_REGISTRY;
```


## Functions
### constructor


```solidity
constructor(address augustusRegistry);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`augustusRegistry`|`address`|The address of Velora's registry of Augustus contracts.|


### buy

Buys an exact amount. Uses the entire balance of the inputToken in the adapter as the maximum input amount if
the amount to buy is adjusted.

*The quoted sell amount will change only if its offset is not zero.*


```solidity
function buy(
    address augustus,
    bytes memory callData,
    address inputToken,
    address outputToken,
    uint256 newOutputAmount,
    Offsets calldata offsets,
    address receiver
) public returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`augustus`|`address`|Address of the swapping contract. Must be in Velora's Augustus registry.|
|`callData`|`bytes`|Swap data to call `augustus`. Contains routing information.|
|`inputToken`|`address`|Token to sell.|
|`outputToken`|`address`|Token to buy.|
|`newOutputAmount`|`uint256`|Adjusted amount to buy. Will be used to update callData before sent to Augustus contract.|
|`offsets`|`Offsets`|Offsets in callData of the exact buy amount (`exactAmount`), maximum sell amount (`limitAmount`) and quoted sell amount (`quotedAmount`).|
|`receiver`|`address`|Address to which leftover `inputToken` assets will be sent. `outputToken` assets may also be sent to this address if the receiver on the `callData` passed to `buy` is set to the VeloraAdapter.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|excessInputAmount The amount of `inputToken` that was not used in the swap.|


### _exactOutputSwap

*Executes the swap specified by `callData` with `augustus`.*


```solidity
function _exactOutputSwap(
    address augustus,
    bytes memory callData,
    address inputToken,
    address outputToken,
    address receiver
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`augustus`|`address`|Address of the swapping contract. Must be in Velora's Augustus registry.|
|`callData`|`bytes`|Swap data to call `augustus`. Contains routing information.|
|`inputToken`|`address`|Token to sell.|
|`outputToken`|`address`|Token to buy.|
|`receiver`|`address`|Address to which leftover `outputToken` assets in the VeloraAdapter will be sent. This can occur if the receiver on the `callData` is set to the VeloraAdapter.|


### _updateAmounts

Sets exact amount in `callData` to `exactAmount`, and limit amount to `limitAmount`.

If `offsets.quotedAmount` is not zero, proportionally scale quoted amount in `callData`.


```solidity
function _updateAmounts(
    bytes memory callData,
    Offsets calldata offsets,
    uint256 exactAmount,
    uint256 limitAmount,
    Math.Rounding rounding
) internal pure;
```

