/**
 * Strategy-based data extractor
 * Fetches and stores price data for leverage token strategies
 */

import { AdapterName, BinanceAdapter, DeFiLlamaAdapter } from './adapters';
import { DataManager } from './data-manager';
import { StrategyConfig } from '../types/strategy';
import { TimeRange, AssetConfig } from '../types/data-sources';

export class StrategyExtractor {
  private dataManager: DataManager;
  private binanceAdapter: BinanceAdapter;
  private defiLlamaAdapter: DeFiLlamaAdapter;

  constructor(dataDir: string = './data') {
    this.dataManager = new DataManager(dataDir);
    this.binanceAdapter = new BinanceAdapter();
    this.defiLlamaAdapter = new DeFiLlamaAdapter();
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
    timeRange: TimeRange
  ): Promise<void> {
    console.log(`\n📦 Processing ${symbol}...`);

    // Determine adapter and source
    const adapter = config.chain && config.address
      ? this.defiLlamaAdapter
      : this.binanceAdapter;

    const source = adapter.name;

    // Use DataManager to ensure data (with gap detection)
    await this.dataManager.ensureData(
      symbol,
      source,
      config.timeframe,
      timeRange,
      async (gap) => {
        return await adapter.fetchPriceData(config, gap);
      }
    );
  }
}
