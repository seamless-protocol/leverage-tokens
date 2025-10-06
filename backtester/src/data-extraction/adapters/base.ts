/**
 * Base adapter interface for price data extraction
 * All price data sources (Binance, DeFiLlama, etc.) implement this interface
 */

import { AssetConfig, PricePoint, TimeRange } from '../../types/data-sources';

export interface PriceDataAdapter {
  /**
   * Name of the data source (e.g., 'binance', 'defillama')
   */
  readonly name: string;

  /**
   * Fetch price data for an asset within a time range
   * Returns array of price points (timestamp + price only)
   */
  fetchPriceData(asset: AssetConfig, timeRange: TimeRange): Promise<PricePoint[]>;

  /**
   * Validate if this adapter can handle the given asset configuration
   */
  canHandle(asset: AssetConfig): boolean;
}
