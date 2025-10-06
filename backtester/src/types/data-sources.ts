/**
 * Common types for data extraction from multiple sources
 */

import { AdapterName } from "../data-extraction/adapters";

export type Timeframe = '1m' | '3m' | '5m' | '15m' | '30m' | '1h' | '4h' | '1d' | '1w';

export type Chain = 'ethereum' | 'base';

/**
 * Time range for data fetching
 */
export interface TimeRange {
  /** Start timestamp (Unix seconds) */
  from: number;

  /** End timestamp (Unix seconds) */
  to: number;
}

/**
 * Single price point - unified format for all data sources
 */
export interface PricePoint {
  timestamp: number;
  price: number;
}

/**
 * Asset data stored in JSON files
 */
export interface AssetData {
  symbol: string;
  source: AdapterName;
  timeframe: Timeframe;
  data: PricePoint[];
}

/**
 * Configuration for fetching asset price data
 */
export interface AssetConfig {
  /** Asset symbol (e.g., 'ETH', 'weETH') */
  symbol: string;

  /** Blockchain chain (optional, required for DeFiLlama) */
  chain?: Chain | null;

  /** Contract address (optional, required for DeFiLlama) */
  address?: string | null;

  /** Timeframe for prices */
  timeframe: Timeframe;
}
