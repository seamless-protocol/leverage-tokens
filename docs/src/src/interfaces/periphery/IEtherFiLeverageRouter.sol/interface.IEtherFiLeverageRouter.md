# IEtherFiLeverageRouter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/002c85336929e7b2f8b2193e3cb727fe9cf4b9e6/src/interfaces/periphery/IEtherFiLeverageRouter.sol)

**Inherits:**
[ILeverageRouterBase](/src/interfaces/periphery/ILeverageRouterBase.sol/interface.ILeverageRouterBase.md)


## Functions
### etherFiL2ModeSyncPool

The EtherFi L2 Mode Sync Pool contract


```solidity
function etherFiL2ModeSyncPool() external view returns (IEtherFiL2ModeSyncPool _etherFiL2ModeSyncPool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_etherFiL2ModeSyncPool`|`IEtherFiL2ModeSyncPool`|The EtherFi L2 Mode Sync Pool contract|


### deposit

Deposit equity into a LeverageToken that uses weETH as collateral and WETH as debt

*Transfers `equityInCollateralAsset` of weETH to the LeverageRouter, flash loans the additional weETH collateral
required to add the equity to the LeverageToken, receives WETH debt, then unwraps the WETH debt to ETH and deposits
the ETH into the EtherFi L2 Mode Sync Pool to obtain weETH. The received weETH is used to repay the flash loan*


```solidity
function deposit(ILeverageToken token, uint256 equityInCollateralAsset, uint256 minShares) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`ILeverageToken`|LeverageToken to deposit equity into|
|`equityInCollateralAsset`|`uint256`|The amount of weETH equity to deposit into the LeverageToken.|
|`minShares`|`uint256`|Minimum shares (LeverageTokens) to receive from the deposit|


