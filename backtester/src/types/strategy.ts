/**
 * Strategy configuration types
 */

import { Chain, TimeRange } from './data-sources';
import { DataAdapter } from '../data-extraction/adapters/base';

/**
 * Token configuration with price adapter specification
 */
export interface TokenConfig {
  symbol: string;
  chain?: Chain;
  address?: string;
  adapter: DataAdapter;
}

/**
 * Leverage token strategy configuration
 */
export interface StrategyConfig {
  /** Strategy name (e.g., 'WEETH-WETH-17x') */
  name: string;

  /** Collateral token (first part, e.g., 'WEETH') */
  collateral: TokenConfig;

  /** Debt/base token (second part, e.g., 'WETH') */
  debt: TokenConfig;

  /** Leverage multiplier (e.g., 17) */
  leverage: number;

  /** Collateral ratio bounds */
  collateralRatios: {
    min: number;
    target: number;
    max: number;
  };

  /** TimeRange for prices data */
  timeRangeData: TimeRange;

  /** Lending market configuration */
  lendingMarket: {
    marketId: string;
    adapter: DataAdapter;
    chainId: number;
  };
}

/**
 * Predefined strategies
 */
export const STRATEGIES: Record<string, StrategyConfig> = {
  'WEETH-WETH-17x': {
    name: 'WEETH-WETH-17x',
    collateral: {
      symbol: 'weETH',
      chain: 'ethereum',
      address: '0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee',
      adapter: DataAdapter.DEFILLAMA,
    },
    debt: {
      symbol: 'ETH',
      adapter: DataAdapter.BINANCE,
    },
    leverage: 17,
    collateralRatios: {
      min: 1.06135,
      target: 1.0625,
      max: 1.062893082,
    },
    timeRangeData: {
      from: Math.floor(new Date('2025-01-01').getTime() / 1000), // january 1st 2025
      to: Math.floor(new Date('2025-09-30').getTime() / 1000), // september 30th 2025
    },
    lendingMarket: {
      marketId: '0xfd0895ba253889c243bf59bc4b96fd1e06d68631241383947b04d1c293a0cfea',
      adapter: DataAdapter.MORPHO,
      chainId: 8453, // Base
    },
  },
};
