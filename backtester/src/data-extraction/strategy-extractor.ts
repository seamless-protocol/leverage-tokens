/**
 * Strategy-based data extractor
 * Fetches and stores price data for leverage token strategies
 */

import { DataManager } from './data-manager';
import { StrategyConfig } from '../types/strategy';
import { TimeRange, AssetConfig } from '../types/data-sources';
import { DataAdapter, IDataAdapter } from './adapters/base';
import { getAdapter } from './adapters';

export class StrategyExtractor {
  private dataManager: DataManager;

  private debtAdapter: IDataAdapter;
  private collateralAdapter: IDataAdapter;
  private lendingAdapter: IDataAdapter;

  constructor(strategy: StrategyConfig, dataDir: string = './data') {
    this.dataManager = new DataManager(dataDir);

    this.debtAdapter = getAdapter(strategy.debt.adapter);
    this.collateralAdapter = getAdapter(strategy.collateral.adapter);
    this.lendingAdapter = getAdapter(strategy.lendingMarket.adapter);
  }

  /**
   * Extract price data for a strategy
   */
  async extract(strategy: StrategyConfig, timeRange: TimeRange): Promise<void> {
    console.log(`\n🎯 Extracting data for strategy: ${strategy.name}\n`);

    // Extract debt token (e.g., ETH from Binance)
    await this.extractAsset(
      strategy.debt.symbol,
      {
        symbol: strategy.debt.symbol,
        chain: strategy.debt.chain || null,
        address: strategy.debt.address || null,
        timeframe: '5m', // High frequency for base asset
      },
      this.debtAdapter,
      timeRange
    );

    // Extract collateral token (e.g., weETH from DeFiLlama)
    await this.extractAsset(
      strategy.collateral.symbol,
      {
        symbol: strategy.collateral.symbol,
        chain: strategy.collateral.chain || null,
        address: strategy.collateral.address || null,
        timeframe: '1h', // Lower frequency for LST
      },
      this.collateralAdapter,
      timeRange
    );

    // Extract lending market borrow APY
    await this.extractAsset(
      `${strategy.lendingMarket.adapter.toUpperCase()}-${strategy.lendingMarket.marketId.substring(0, 10)}`,
      {
        symbol: `borrow-apy`,
        timeframe: '1d',
        lendingMarketId: strategy.lendingMarket.marketId,
        lendingAdapter: strategy.lendingMarket.adapter,
        chainId: strategy.lendingMarket.chainId,
      },
      this.lendingAdapter,
      timeRange
    );

    console.log(`\n✅ Data extraction complete for ${strategy.name}\n`);
  }

  /**
   * Extract data for a single asset
   */
  private async extractAsset(
    symbol: string,
    config: AssetConfig,
    adapter: IDataAdapter,
    timeRange: TimeRange
  ): Promise<void> {
    console.log(`\n📦 Processing ${symbol}...`);
    // Use DataManager to ensure data (with gap detection)
    await this.dataManager.ensureData(
      symbol,
      adapter.name,
      config.timeframe,
      timeRange,
      async (gap) => {
        return await adapter.fetchPriceData(config, gap);
      }
    );
  }
}
