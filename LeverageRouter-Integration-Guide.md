# LeverageRouter Integration Guide

This guide explains how to integrate with Seamless Protocol's leverage tokens using the `LeverageRouter` contract for minting (depositing) and redeeming leverage token shares.

## Overview

The `LeverageRouter` is an immutable periphery contract that facilitates deposits and redemptions from LeverageTokens using flash loans and token swaps. It abstracts away the complexity of:

1. Flash loaning debt assets from Morpho
2. Swapping between collateral and debt assets
3. Managing the deposit/redeem mechanics with the `LeverageManager`

## Contract Addresses

### Base (Chain ID: 8453)

| Contract | Address |
|----------|---------|
| LeverageRouter | `0x00c66934EBCa0F2A845812bC368B230F6da11A5C` |
| LeverageManager | `0x38Ba21C6Bf31dF1b1798FCEd07B4e9b07C5ec3a8` |
| MulticallExecutor | `0x9D04f65b58cED1fddef50AEc8b0b3d64fE64220E` |

### Ethereum Mainnet (Chain ID: 1)

| Contract | Address |
|----------|---------|
| LeverageRouter | `0xb0764dE7eeF0aC69855C431334B7BC51A96E6DbA` |
| LeverageManager | `0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351` |
| MulticallExecutor | `0x16D02Ebd89988cAd1Ce945807b963aB7A9Fd22E1` |

---

## Minting (Deposit) Flow

### High-Level Flow

1. User calls `deposit()` with collateral amount and swap parameters
2. Router flash loans debt from Morpho
3. Router executes swap calls to convert debt → collateral via the `MulticallExecutor`
4. Router deposits total collateral (user's + swapped) into the LeverageToken
5. Router repays flash loan with debt received from deposit
6. Router transfers LeverageToken shares and any excess debt to user

### Function Signature

```solidity
function deposit(
    ILeverageToken leverageToken,
    uint256 collateralFromSender,
    uint256 flashLoanAmount,
    uint256 minShares,
    IMulticallExecutor multicallExecutor,
    IMulticallExecutor.Call[] calldata swapCalls
) external;
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `leverageToken` | Address of the LeverageToken to mint shares of |
| `collateralFromSender` | Amount of collateral asset the user provides (must be pre-approved) |
| `flashLoanAmount` | Amount of debt asset to flash loan (will be swapped to collateral) |
| `minShares` | Minimum shares to receive (slippage protection) |
| `multicallExecutor` | Contract that executes the swap calls |
| `swapCalls` | Array of calls to execute for swapping debt → collateral |

### Preview Function

Before calling `deposit()`, use `previewDeposit()` to estimate the outcome:

```solidity
function previewDeposit(ILeverageToken token, uint256 collateralFromSender)
    external
    view
    returns (ActionData memory);
```

Returns:
- `collateral`: Total collateral that will be added
- `debt`: Amount of debt that will be borrowed
- `shares`: Amount of shares that will be minted
- `tokenFee`: Fee in shares for the LeverageToken
- `treasuryFee`: Fee in shares for the treasury

### TypeScript Example (from Seamless Frontend)

```typescript
import { encodeFunctionData, erc20Abi } from 'viem'

// 1. Preview the deposit to get expected values
const routerPreview = await readLeverageRouterV2PreviewDeposit(wagmiConfig, {
  args: [leverageTokenAddress, equityInCollateralAsset],
  chainId,
})

// 2. Calculate flash loan amount with slippage buffer
const flashLoanAmount = applySlippageFloor(routerPreview.debt, slippageBps)

// 3. Get a quote for swapping debt to collateral
// Using your preferred DEX aggregator (Uniswap, LiFi, etc.)
const swapQuote = await quoteDebtToCollateral({
  intent: 'exactIn',
  inToken: debtAsset,
  outToken: collateralAsset,
  amountIn: flashLoanAmount,
  slippageBps: quoteSlippageBps,
})

// 4. Build the swap calls
// First call: approve the DEX to spend debt tokens
const approvalCall = {
  target: debtAsset,
  data: encodeFunctionData({
    abi: erc20Abi,
    functionName: 'approve',
    args: [swapQuote.approvalTarget, flashLoanAmount],
  }),
  value: 0n,
}

// Additional calls from the quote (the actual swap)
const calls = [approvalCall, ...swapQuote.calls]

// 5. Approve the LeverageRouter to spend collateral
await writeErc20Approve({
  address: collateralAsset,
  args: [leverageRouterAddress, collateralFromSender],
})

// 6. Execute the deposit
await writeLeverageRouterV2Deposit({
  args: [
    leverageTokenAddress,
    collateralFromSender,
    flashLoanAmount,
    minShares,
    multicallExecutorAddress,
    calls,
  ],
})
```

### Solidity Example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageRouter} from "./interfaces/periphery/ILeverageRouter.sol";
import {ILeverageToken} from "./interfaces/ILeverageToken.sol";
import {IMulticallExecutor} from "./interfaces/periphery/IMulticallExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LeverageTokenMinter {
    ILeverageRouter public immutable leverageRouter;
    IMulticallExecutor public immutable multicallExecutor;
    
    constructor(ILeverageRouter _router, IMulticallExecutor _executor) {
        leverageRouter = _router;
        multicallExecutor = _executor;
    }
    
    function mintLeverageToken(
        ILeverageToken leverageToken,
        IERC20 collateralAsset,
        IERC20 debtAsset,
        uint256 collateralAmount,
        uint256 flashLoanAmount,
        uint256 minShares,
        IMulticallExecutor.Call[] calldata swapCalls
    ) external {
        // Transfer collateral from user
        collateralAsset.transferFrom(msg.sender, address(this), collateralAmount);
        
        // Approve router to spend collateral
        collateralAsset.approve(address(leverageRouter), collateralAmount);
        
        // Execute deposit
        leverageRouter.deposit(
            leverageToken,
            collateralAmount,
            flashLoanAmount,
            minShares,
            multicallExecutor,
            swapCalls
        );
        
        // Transfer received shares to user
        uint256 sharesReceived = leverageToken.balanceOf(address(this));
        leverageToken.transfer(msg.sender, sharesReceived);

        // Transfer excess debt to user
        uint256 debtReceived = debtAsset.balanceOf(address(this));
        debtAsset.transfer(msg.sender, debtReceived);
    }
}
```

---

## Redeeming Flow

### High-Level Flow

1. User calls `redeem()` with shares and swap parameters
2. Router flash loans debt from Morpho (amount needed to repay position)
3. Router redeems shares from LeverageToken, receiving collateral
4. Router executes swap calls to convert collateral → debt via `MulticallExecutor`
5. Router repays flash loan with swapped debt
6. Router transfers remaining collateral and debt to user

### Function Signature

```solidity
function redeem(
    ILeverageToken token,
    uint256 shares,
    uint256 minCollateralForSender,
    IMulticallExecutor multicallExecutor,
    IMulticallExecutor.Call[] calldata swapCalls
) external;
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `token` | Address of the LeverageToken to redeem shares from |
| `shares` | Amount of shares to redeem (must be pre-approved) |
| `minCollateralForSender` | Minimum collateral to receive (slippage protection) |
| `multicallExecutor` | Contract that executes the swap calls |
| `swapCalls` | Array of calls to execute for swapping collateral → debt |

### TypeScript Example

```typescript
import { encodeFunctionData, erc20Abi } from 'viem'

// 1. Preview the redemption
const preview = await readLeverageManagerV2PreviewRedeem(wagmiConfig, {
  args: [leverageTokenAddress, sharesToRedeem],
  chainId,
})

// 2. Calculate minimum collateral with slippage
const minCollateralForSender = applySlippageFloor(previewEquity, slippageBps)

// 3. Calculate collateral to swap (total collateral minus what user keeps)
const collateralToSpend = preview.collateral - minCollateralForSender

// 4. Get a quote for swapping collateral to debt
const swapQuote = await quoteCollateralToDebt({
  intent: 'exactIn',
  inToken: collateralAsset,
  outToken: debtAsset,
  amountIn: collateralToSpend,
  slippageBps: quoteSlippageBps,
})

// 5. Build the swap calls
const approvalCall = {
  target: collateralAsset,
  data: encodeFunctionData({
    abi: erc20Abi,
    functionName: 'approve',
    args: [swapQuote.approvalTarget, collateralToSpend],
  }),
  value: 0n,
}

const calls = [approvalCall, ...swapQuote.calls]

// 6. Approve the LeverageRouter to spend shares
await writeErc20Approve({
  address: leverageTokenAddress,
  args: [leverageRouterAddress, sharesToRedeem],
})

// 7. Execute the redemption
await writeLeverageRouterV2Redeem({
  args: [
    leverageTokenAddress,
    sharesToRedeem,
    minCollateralForSender,
    multicallExecutorAddress,
    calls,
  ],
})
```


### Solidity Example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILeverageRouter} from "./interfaces/periphery/ILeverageRouter.sol";
import {ILeverageToken} from "./interfaces/ILeverageToken.sol";
import {IMulticallExecutor} from "./interfaces/periphery/IMulticallExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LeverageTokenRedeemer {
    ILeverageRouter public immutable leverageRouter;
    IMulticallExecutor public immutable multicallExecutor;
    
    constructor(ILeverageRouter _router, IMulticallExecutor _executor) {
        leverageRouter = _router;
        multicallExecutor = _executor;
    }
    
    function mintLeverageToken(
        ILeverageToken leverageToken,
        IERC20 collateralAsset,
        IERC20 debtAsset,
        uint256 shares,
        uint256 minCollateral,
        IMulticallExecutor.Call[] calldata swapCalls
    ) external {
        // Transfer shares from user
        leverageToken.transferFrom(msg.sender, address(this), shares);
        
        // Approve router to spend collateral
        leverageToken.approve(address(leverageRouter), shares);
        
        // Execute redeem
        leverageRouter.redeem(
            leverageToken,
            shares,
            minCollateral,
            multicallExecutor,
            swapCalls
        );
        
        // Transfer received collateral to user
        uint256 collateralReceived = collateralAsset.balanceOf(address(this));
        collateralAsset.transfer(msg.sender, collateralReceived);

        // Transfer excess debt to user
        uint256 debtReceived = debtAsset.balanceOf(address(this));
        debtAsset.transfer(msg.sender, debtReceived);
    }
}
```

---

## MulticallExecutor

The `MulticallExecutor` is a helper contract that executes arbitrary calls and sweeps remaining tokens back to the caller.

### Call Structure

```solidity
struct Call {
    address target;  // Contract to call
    uint256 value;   // ETH value to send
    bytes data;      // Calldata to execute
}
```

### How It Works

1. Router sends tokens (debt or collateral) to the MulticallExecutor
2. MulticallExecutor executes all provided calls sequentially
3. After execution, it sweeps specified tokens back to the Router

The `swapCalls` array typically contains:
1. An approval call (approve DEX router to spend tokens)
2. One or more swap calls (the actual DEX swap)

---

## Building Swap Calls

### Using DEX Aggregators

For production use, integrate with DEX aggregators like:

- **LiFi** - Cross-chain aggregator with wide DEX coverage
- **ParaSwap/Velora** - Popular aggregator for exact-out swaps
- **0x API** - Professional-grade aggregation
- **Uniswap** - Direct pool swaps

### Example: Uniswap V3 Swap Calls

```typescript
const swapRouterAddress = '0xE592427A0AEce92De3Edee1F18E0157C05861564'

// Approval call
const approvalCall = {
  target: debtAssetAddress,
  data: encodeFunctionData({
    abi: erc20Abi,
    functionName: 'approve',
    args: [swapRouterAddress, amountIn],
  }),
  value: 0n,
}

// Swap call
const swapCall = {
  target: swapRouterAddress,
  data: encodeFunctionData({
    abi: swapRouterAbi,
    functionName: 'exactInputSingle',
    args: [{
      tokenIn: debtAssetAddress,
      tokenOut: collateralAssetAddress,
      fee: 3000, // 0.3% fee tier
      recipient: multicallExecutorAddress, // Tokens go to executor, then swept
      deadline: BigInt(Math.floor(Date.now() / 1000) + 900),
      amountIn: amountIn,
      amountOutMinimum: minAmountOut,
      sqrtPriceLimitX96: 0n,
    }],
  }),
  value: 0n,
}

const calls = [approvalCall, swapCall]
```

---

## Slippage Protection

### For Deposits

1. **Share slippage**: Use `minShares` parameter to protect against receiving fewer shares than expected
2. **Swap slippage**: Build slippage into your DEX quote (e.g., `amountOutMinimum` for Uniswap)

### For Redemptions

1. **Collateral slippage**: Use `minCollateralForSender` parameter
2. **Swap slippage**: Build into your DEX quote

### Calculating Slippage

```typescript
// Apply slippage floor (for minimums)
function applySlippageFloor(amount: bigint, slippageBps: number): bigint {
  const factor = 10000n - BigInt(slippageBps)
  return (amount * factor) / 10000n
}

// Apply slippage ceiling (for maximums)
function applySlippageCeiling(amount: bigint, slippageBps: number): bigint {
  const factor = 10000n + BigInt(slippageBps)
  return (amount * factor) / 10000n
}

// Example: 50 bps (0.5%) slippage
const minShares = applySlippageFloor(expectedShares, 50)
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `CollateralSlippageTooHigh` | Received less collateral than `minCollateralForSender` | Increase slippage tolerance or retry |
| `InsufficientCollateralForDeposit` | Swap output + user collateral < required | Increase flash loan amount or improve swap quote |
| `Unauthorized` | Flash loan callback called by non-Morpho address | Contract misuse - ensure calling through proper flow |

### Transaction Simulation

Always simulate transactions before execution to catch errors early:

```typescript
// Using viem's simulateContract
const { request } = await publicClient.simulateContract({
  address: leverageRouterAddress,
  abi: leverageRouterAbi,
  functionName: 'deposit',
  args: [leverageToken, collateral, flashLoan, minShares, executor, calls],
  account: userAddress,
})

// If simulation succeeds, execute
const hash = await walletClient.writeContract(request)
```

---

## Frontend Reference Implementation

The Seamless Protocol frontend provides a complete reference implementation:

**Repository**: https://github.com/seamless-protocol/app

### Key Files

| File | Purpose |
|------|---------|
| `src/domain/mint/planner/plan.ts` | Mint planning logic |
| `src/domain/redeem/planner/plan.ts` | Redeem planning logic |
| `src/domain/shared/adapters/` | DEX adapter implementations |
| `src/lib/contracts/addresses.ts` | Contract addresses by chain |
| `src/lib/contracts/generated.ts` | Generated contract bindings |

### Adapter Examples

The frontend includes adapters for multiple DEXes:

- `uniswapV3.ts` - Direct Uniswap V3 integration
- `uniswapV2.ts` - Uniswap V2 style DEXes
- `lifi.ts` - LiFi aggregator integration
- `velora.ts` - Velora/ParaSwap integration

---

## Security Considerations

1. **Approvals**: Only approve the exact amount needed, or use permit2 where available
2. **Slippage**: Always set reasonable `minShares` and `minCollateralForSender` values
3. **DEX Selection**: Use reputable DEXes and aggregators
4. **Quote Freshness**: Quotes expire quickly - fetch fresh quotes before transactions
5. **Flash Loan Risk**: The router handles flash loans atomically - if any step fails, the entire transaction reverts

---

## Gas Optimization Tips

1. **Batch Operations**: If minting multiple times, consider batching approvals
2. **Direct Pools**: For common pairs, direct DEX pool swaps are cheaper than aggregators
3. **Gas Price**: Monitor gas prices and time transactions during lower activity periods

---

## Additional Resources

- [Seamless Protocol Documentation](https://docs.seamlessprotocol.com)
- [Morpho Blue Documentation](https://docs.morpho.org)
- [LeverageToken Contract Source](./src/LeverageToken.sol)
- [LeverageManager Contract Source](./src/LeverageManager.sol)
- [LeverageRouter Contract Source](./src/periphery/LeverageRouter.sol)
