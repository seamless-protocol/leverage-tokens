import { describe, it, expect, beforeEach } from 'vitest';
import { Backtester, HistoricalData, BacktestConfig } from '../Backtester';
import { StrategyConfig } from '../../types/strategy';
import { AssetData } from '../../types/data-sources';
import { DataAdapter } from '../../data-extraction/adapters/base';

describe('Backtester - Happy Path Tests', () => {
  let backtester: Backtester;

  // Realistic strategy config with proper types
  const testStrategy: StrategyConfig = {
    name: 'TEST-2x',
    collateral: {
      symbol: 'ETH',
      adapter: DataAdapter.BINANCE,
    },
    debt: {
      symbol: 'USDC',
      adapter: DataAdapter.BINANCE,
    },
    leverage: 2,
    collateralRatios: {
      min: 1.5,
      target: 2.0,
      max: 2.5,
      preLiquidationThreshold: 1.4,
    },
    timeRangeData: {
      from: 1000,
      to: 2000,
    },
    timeRangeBacktest: {
      from: 1000,
      to: 2000,
    },
    lendingMarket: {
      marketId: '0x1234567890123456789012345678901234567890123456789012345678901234',
      adapter: DataAdapter.MORPHO,
      chainId: 8453,
    },
  };

  beforeEach(() => {
    backtester = new Backtester();
  });

  describe('Error Handling', () => {
    it('should throw error when running without initialization', async () => {
      await expect(async () => {
        await backtester.run();
      }).rejects.toThrow();
    });

    it('should throw error when initializing without loading data', () => {
      expect(() => {
        backtester.initialize({
          strategy: testStrategy,
          initialDepositCollateral: 1.0,
          estimatedRebalanceGasCost: 5,
          managementFeePercentage: 0,
        });
      }).toThrow();
    });

    it('should throw error with empty data', () => {
      const emptyData: HistoricalData = {
        debtPrices: {
          symbol: 'USDC',
          source: DataAdapter.BINANCE,
          timeframe: '5m',
          data: [],
        },
        collateralPrices: {
          symbol: 'ETH',
          source: DataAdapter.BINANCE,
          timeframe: '5m',
          data: [],
        },
        borrowAPY: {
          symbol: 'MORPHO-0x1234567890',
          source: DataAdapter.MORPHO,
          timeframe: '1d',
          data: [],
        },
      };

      backtester.loadData(emptyData);

      expect(() => {
        backtester.initialize({
          strategy: testStrategy,
          initialDepositCollateral: 1.0,
          estimatedRebalanceGasCost: 5,
          managementFeePercentage: 0,
        });
      }).toThrow();
    });
  });

  describe('Simple Backtest - Flat Prices', () => {
    it('should complete backtest with stable prices and return results', async () => {
      const debtPrices: AssetData = {
        symbol: 'USDC',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 1.0 },
          { timestamp: 1500, price: 1.0 },
          { timestamp: 2000, price: 1.0 },
        ],
      };

      const collateralPrices: AssetData = {
        symbol: 'ETH',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 2000 },
          { timestamp: 1500, price: 2000 },
          { timestamp: 2000, price: 2000 },
        ],
      };

      const borrowAPY: AssetData = {
        symbol: 'MORPHO-0x1234567890',
        source: DataAdapter.MORPHO,
        timeframe: '1d',
        data: [{ timestamp: 1000, price: 0.0 }],
      };

      backtester.loadData({ debtPrices, collateralPrices, borrowAPY });
      backtester.initialize({
        strategy: testStrategy,
        initialDepositCollateral: 1.0,
        estimatedRebalanceGasCost: 5,
        managementFeePercentage: 0,
      });

      const result = await backtester.run();

      // Verify result structure
      expect(result.strategyName).toBe('TEST-2x');
      expect(result.period).toBeDefined();
      expect(result.period.start).toBe(1000);
      expect(result.period.end).toBe(2000);
      expect(result.metrics).toBeDefined();
      expect(result.metrics.initialSharePrice).toBeGreaterThan(0);
      expect(result.metrics.finalSharePrice).toBeGreaterThan(0);
      expect(Array.isArray(result.rebalances)).toBe(true);
    });
  });

  describe('Price Increase Scenario', () => {
    it('should show positive return when collateral price increases 10%', async () => {
      const debtPrices: AssetData = {
        symbol: 'USDC',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 1.0 },
          { timestamp: 2000, price: 1.0 },
        ],
      };

      const collateralPrices: AssetData = {
        symbol: 'ETH',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 2000 },
          { timestamp: 2000, price: 2200 }, // +10%
        ],
      };

      const borrowAPY: AssetData = {
        symbol: 'MORPHO-0x1234567890',
        source: DataAdapter.MORPHO,
        timeframe: '1d',
        data: [{ timestamp: 1000, price: 0.0 }],
      };

      backtester.loadData({ debtPrices, collateralPrices, borrowAPY });
      backtester.initialize({
        strategy: testStrategy,
        initialDepositCollateral: 1.0,
        estimatedRebalanceGasCost: 5,
        managementFeePercentage: 0,
      });

      const result = await backtester.run();

      // With 2x leverage and 10% price increase, should be positive
      expect(result.metrics.totalReturn).toBeGreaterThan(0);
      expect(result.metrics.finalSharePrice).toBeGreaterThan(
        result.metrics.initialSharePrice
      );
    });
  });

  describe('Price Decrease Scenario', () => {
    it('should show negative return when collateral price decreases 10%', async () => {
      const debtPrices: AssetData = {
        symbol: 'USDC',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 1.0 },
          { timestamp: 2000, price: 1.0 },
        ],
      };

      const collateralPrices: AssetData = {
        symbol: 'ETH',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 2000 },
          { timestamp: 2000, price: 1800 }, // -10%
        ],
      };

      const borrowAPY: AssetData = {
        symbol: 'MORPHO-0x1234567890',
        source: DataAdapter.MORPHO,
        timeframe: '1d',
        data: [{ timestamp: 1000, price: 0.0 }],
      };

      backtester.loadData({ debtPrices, collateralPrices, borrowAPY });
      backtester.initialize({
        strategy: testStrategy,
        initialDepositCollateral: 1.0,
        estimatedRebalanceGasCost: 5,
        managementFeePercentage: 0,
      });

      const result = await backtester.run();

      // With 2x leverage and -10% price decrease, should be negative
      expect(result.metrics.totalReturn).toBeLessThan(0);
      expect(result.metrics.finalSharePrice).toBeLessThan(
        result.metrics.initialSharePrice
      );
    });
  });

  describe('Result Metrics', () => {
    it('should calculate all required metrics', async () => {
      const debtPrices: AssetData = {
        symbol: 'USDC',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 1.0 },
          { timestamp: 2000, price: 1.0 },
        ],
      };

      const collateralPrices: AssetData = {
        symbol: 'ETH',
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [
          { timestamp: 1000, price: 2000 },
          { timestamp: 2000, price: 2000 },
        ],
      };

      const borrowAPY: AssetData = {
        symbol: 'MORPHO-0x1234567890',
        source: DataAdapter.MORPHO,
        timeframe: '1d',
        data: [{ timestamp: 1000, price: 0.0 }],
      };

      backtester.loadData({ debtPrices, collateralPrices, borrowAPY });
      backtester.initialize({
        strategy: testStrategy,
        initialDepositCollateral: 1.0,
        estimatedRebalanceGasCost: 5,
        managementFeePercentage: 0,
      });

      const result = await backtester.run();

      // Check all metrics exist
      expect(result.metrics.initialSharePrice).toBeDefined();
      expect(result.metrics.finalSharePrice).toBeDefined();
      expect(result.metrics.totalReturn).toBeDefined();
      expect(result.metrics.annualizedReturn).toBeDefined();
      expect(result.metrics.maxDrawdown).toBeDefined();
      expect(result.metrics.rebalanceCount).toBeDefined();
      expect(result.metrics.totalGasCostsUSD).toBeDefined();
      expect(result.metrics.avgCollateralRatio).toBeDefined();
      expect(result.metrics.timesBelowMin).toBeDefined();
      expect(result.metrics.timesAboveMax).toBeDefined();
    });
  });
});
