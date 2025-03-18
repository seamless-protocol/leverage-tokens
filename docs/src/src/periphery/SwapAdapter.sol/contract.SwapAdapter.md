# SwapAdapter
[Git Source](https://github.com/seamless-protocol/ilm-v2/blob/7492e139a233e3537fefd83074042a04664dc27a/src/periphery/SwapAdapter.sol)

**Inherits:**
[ISwapAdapter](/src/interfaces/periphery/ISwapAdapter.sol/interface.ISwapAdapter.md), AccessControlUpgradeable, UUPSUpgradeable


## State Variables
### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


## Functions
### initialize


```solidity
function initialize(address initialAdmin) external initializer;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

### swapExactInput

Swap tokens from the inputToken to the outputToken using the specified provider


```solidity
function swapExactInput(IERC20 inputToken, uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
    external
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputToken`|`IERC20`|Token to swap from|
|`inputAmount`|`uint256`|Amount of tokens to swap|
|`minOutputAmount`|`uint256`|Minimum amount of tokens to receive|
|`swapContext`|`SwapContext`|Swap context to use for the swap (which exchange to use, the swap path, tick spacing, etc.)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|outputAmount Amount of tokens received|


### swapExactOutput

Swap tokens from the inputToken to the outputToken using the specified provider


```solidity
function swapExactOutput(
    IERC20 inputToken,
    uint256 outputAmount,
    uint256 maxInputAmount,
    SwapContext memory swapContext
) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`inputToken`|`IERC20`|Token to swap from|
|`outputAmount`|`uint256`|Amount of tokens to receive|
|`maxInputAmount`|`uint256`|Maximum amount of tokens to swap|
|`swapContext`|`SwapContext`|Swap context to use for the swap (which exchange to use, the swap path, tick spacing, etc.)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|inputAmount Amount of tokens swapped|


### _swapAerodrome


```solidity
function _swapAerodrome(
    uint256 inputAmount,
    uint256 minOutputAmount,
    address receiver,
    address aerodromeRouter,
    address aerodromePoolFactory,
    address[] memory path
) internal returns (uint256 outputAmount);
```

### _swapExactInputAerodrome


```solidity
function _swapExactInputAerodrome(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 outputAmount);
```

### _swapExactInputAerodromeSlipstream


```solidity
function _swapExactInputAerodromeSlipstream(
    uint256 inputAmount,
    uint256 minOutputAmount,
    SwapContext memory swapContext
) internal returns (uint256 outputAmount);
```

### _swapExactInputUniV2


```solidity
function _swapExactInputUniV2(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 outputAmount);
```

### _swapExactInputUniV3


```solidity
function _swapExactInputUniV3(uint256 inputAmount, uint256 minOutputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 outputAmount);
```

### _swapExactOutputAerodrome


```solidity
function _swapExactOutputAerodrome(uint256 outputAmount, uint256 maxInputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 inputAmount);
```

### _swapExactOutputAerodromeSlipstream


```solidity
function _swapExactOutputAerodromeSlipstream(
    uint256 outputAmount,
    uint256 maxInputAmount,
    SwapContext memory swapContext
) internal returns (uint256 inputAmount);
```

### _swapExactOutputUniV2


```solidity
function _swapExactOutputUniV2(uint256 outputAmount, uint256 maxInputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 inputAmount);
```

### _swapExactOutputUniV3


```solidity
function _swapExactOutputUniV3(uint256 outputAmount, uint256 maxInputAmount, SwapContext memory swapContext)
    internal
    returns (uint256 inputAmount);
```

### _generateAerodromeRoutes

Generate the array of Routes as required by the Aerodrome router


```solidity
function _generateAerodromeRoutes(address[] memory path, address aerodromePoolFactory)
    internal
    pure
    returns (IAerodromeRouter.Route[] memory routes);
```

### _reversePath

Reverses a path of addresses


```solidity
function _reversePath(address[] memory path) internal pure returns (address[] memory reversedPath);
```

