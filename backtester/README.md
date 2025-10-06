# Leverage Token Backtester

Backtester for leverage token strategies (e.g., weETH-WETH-17x).

## Architecture

### Phase 1: Data Extraction ✅

Fetch and store price data for leverage token strategies with intelligent caching.

**Key Features:**
- **Unified format**: All data stored as `{ timestamp, price }` (no OHLCV overhead)
- **Gap detection**: Only fetches missing data (never re-downloads)
- **Single files per asset**: `ETH.json`, `weETH.json` (append-only)
- **Strategy-based**: Define strategies, not individual assets

### Data Structure

```
data/
├─ ETH.json          # Base asset (Binance, 5min)
├─ weETH.json        # Collateral asset (DeFiLlama, daily interpolated to 1hr)
└─ stETH.json        # Future strategies
```

**File Format:**
```json
{
  "symbol": "ETH",
  "source": "binance",
  "timeframe": "5m",
  "data": [
    { "timestamp": 1704067200, "price": 2300.50 },
    { "timestamp": 1704067500, "price": 2301.20 },
    ...
  ]
}
```

## Usage

### 1. Extract Price Data

```bash
pnpm extract
```

This will:
1. Load strategy config (`WEETH-WETH-17x`)
2. Check existing data files
3. Fetch only missing gaps
4. Save to `data/ETH.json` and `data/weETH.json`

**Example output:**
```
🎯 Extracting data for strategy: WEETH-WETH-17x

📦 Processing ETH...
🔍 [Gap] ETH has 1 gap(s) to fetch
  ↳ Fetching gap: 2024-01-01 → 2024-01-08
📥 [Binance] Fetching ETHUSDT (5m)
✅ [Binance] Fetched 2016 price points
💾 [Save] ETH.json (2016 price points)

📦 Processing weETH...
📥 [DeFiLlama] Fetching weETH
  ↳ Fetching 273 daily points
  ↳ Batch 1/28
  ...
✅ [DeFiLlama] Fetched 273 daily points, interpolated to 6552 hourly points
💾 [Save] weETH.json (6552 price points)

✅ Data extraction complete for WEETH-WETH-17x
```

### 2. Add New Strategies

Edit `src/types/strategy.ts`:

```typescript
export const STRATEGIES = {
  'WEETH-WETH-17x': { ... },

  // Add new strategy
  'stETH-WETH-5x': {
    name: 'stETH-WETH-5x',
    collateral: {
      symbol: 'stETH',
      chain: 'ethereum',
      address: '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84',
    },
    debt: {
      symbol: 'WETH',
    },
    leverage: 5,
    collateralRatios: { min: 1.2, target: 1.25, max: 1.3 },
    timeRangeData: {
      from: Math.floor(new Date('2025-01-01').getTime() / 1000),
      to: Math.floor(new Date('2025-09-30').getTime() / 1000),
    },
  },
}
```

### 3. Gap Detection in Action

```bash
# First run: Fetches data for timeRangeData in strategy
pnpm extract

# Edit strategy.timeRangeData to extend the date range
# Second run: Only fetches the missing gap!
pnpm extract
```

## Project Structure

```
backtester/
├── src/
│   ├── data-extraction/
│   │   ├── adapters/
│   │   │   ├── base.ts           # Adapter interface
│   │   │   ├── binance.ts        # Binance API (CEX)
│   │   │   └── defillama.ts      # DeFiLlama API (DEX)
│   │   ├── data-manager.ts       # Storage + gap detection
│   │   ├── strategy-extractor.ts # Strategy-based extraction
│   │   └── extract.ts            # CLI entry point
│   └── types/
│       ├── data-sources.ts       # PricePoint, AssetData
│       └── strategy.ts           # StrategyConfig, STRATEGIES
├── data/                         # Extracted price data (gitignored)
└── package.json
```

## Design Decisions

### Why unified `PricePoint` format?

- **Simpler**: No need for OHLCV complexity
- **Smaller**: ~80% less storage
- **Sufficient**: Backtesting only needs close prices

### Why not store weETH/ETH ratio?

- **Derived data**: Calculated as `weETH_USD / ETH_USD`
- **Flexibility**: Can change ratio calculation in simulation
- **No redundancy**: Don't store what you can compute

### Why gap detection?

- **Never re-fetch**: Append-only files
- **Incremental**: Fetch only missing data
- **Reusable**: ETH.json works for multiple strategies

## Next Steps

- **Phase 2**: Simulation engine (coming soon)
- **Phase 3**: Rebalance strategies (coming soon)

## Commands

```bash
# Extract data for strategies
pnpm extract

# Build TypeScript
pnpm build

# Run main entry point
pnpm dev
```
