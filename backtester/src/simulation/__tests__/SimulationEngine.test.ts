import { describe, it, expect, beforeEach } from 'vitest';
import { SimulationEngine, SimulationConfig } from '../SimulationEngine';
import { MarketPrices } from '../types';

describe('SimulationEngine - Happy Path Tests', () => {
  let engine: SimulationEngine;
  const DECIMALS = 1e18;

  // Simple 2x leverage config
  const simpleConfig: SimulationConfig = {
    initialCollateral: BigInt(Math.floor(2 * DECIMALS)), // 2 ETH collateral
    initialDebt: BigInt(Math.floor(1 * DECIMALS)), // 1 ETH debt
    initialShares: BigInt(Math.floor(1 * DECIMALS)), // 1 share
    collateralRatios: {
      min: 1.5,
      target: 2.0,
      max: 2.5,
      preLiquidationThreshold: 1.4,
    },
    startTimestamp: 1000,
    estimatedRebalanceGasCost: 5,
    managementFeePercentage: 0,
  };

  beforeEach(() => {
    engine = new SimulationEngine(simpleConfig);
  });

  describe('Collateral Ratio', () => {
    it('should calculate ratio = 2.0 when collateral is 2x debt in value', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 1000,
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      // 2 ETH * $1000 = $2000 collateral
      // 1 ETH * $1000 = $1000 debt
      // Ratio = 2000 / 1000 = 2.0
      const ratio = engine.calculateCollateralRatio(prices);
      expect(ratio).toBeCloseTo(2.0, 4);
    });

    it('should calculate ratio = 4.0 when collateral price doubles', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 2000, // 2x price
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      // 2 ETH * $2000 = $4000 collateral
      // 1 ETH * $1000 = $1000 debt
      // Ratio = 4000 / 1000 = 4.0
      const ratio = engine.calculateCollateralRatio(prices);
      expect(ratio).toBeCloseTo(4.0, 4);
    });

    it('should calculate ratio = 1.0 when collateral price halves', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 500, // 0.5x price
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      // 2 ETH * $500 = $1000 collateral
      // 1 ETH * $1000 = $1000 debt
      // Ratio = 1000 / 1000 = 1.0
      const ratio = engine.calculateCollateralRatio(prices);
      expect(ratio).toBeCloseTo(1.0, 4);
    });
  });

  describe('Rebalance Detection', () => {
    it('should NOT need rebalance when ratio is within bounds [1.5, 2.5]', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 1000,
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      // Ratio = 2.0 (within bounds)
      const result = engine.checkRebalanceNeeded(prices);
      expect(result.needed).toBe(false);
      expect(result.currentRatio).toBeCloseTo(2.0, 2);
    });

    it('should report correct ratio when out of bounds', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 400, // Makes ratio = 0.8 (below min 1.5)
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      const result = engine.checkRebalanceNeeded(prices);
      expect(result.currentRatio).toBeCloseTo(0.8, 2);
    });
  });

  describe('Rebalance Execution', () => {
    it('should bring ratio back to target (2.0) after DOWN rebalance', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 600, // Ratio = 1.2 (below min)
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      const ratioBefore = engine.calculateCollateralRatio(prices);
      expect(ratioBefore).toBeLessThan(1.5); // Below min

      // Rebalance DOWN
      engine.rebalance(prices, 'DOWN');

      const ratioAfter = engine.calculateCollateralRatio(prices);
      expect(ratioAfter).toBeCloseTo(2.0, 1); // Should be at target
    });

    it('should bring ratio back to target (2.0) after UP rebalance', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 1400, // Ratio = 2.8 (above max 2.5)
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      const ratioBefore = engine.calculateCollateralRatio(prices);
      expect(ratioBefore).toBeGreaterThan(2.5); // Above max

      // Rebalance UP
      engine.rebalance(prices, 'UP');

      const ratioAfter = engine.calculateCollateralRatio(prices);
      expect(ratioAfter).toBeCloseTo(2.0, 1); // Should be at target
    });

    it('should reduce debt in DOWN rebalance', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 600,
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      const debtBefore = engine.getState().debtAmount;
      engine.rebalance(prices, 'DOWN');
      const debtAfter = engine.getState().debtAmount;

      expect(debtAfter).toBeLessThan(debtBefore);
    });

    it('should increase debt in UP rebalance', () => {
      const prices: MarketPrices = {
        collateralPriceUSD: 1400,
        debtPriceUSD: 1000,
        timestamp: 1000,
      };

      const debtBefore = engine.getState().debtAmount;
      engine.rebalance(prices, 'UP');
      const debtAfter = engine.getState().debtAmount;

      expect(debtAfter).toBeGreaterThan(debtBefore);
    });
  });

  describe('Interest Accrual', () => {
    it('should NOT accrue interest when APY is 0%', () => {
      const debtBefore = engine.getState().debtAmount;

      // 1 year with 0% APY
      const borrowRate = { apy: 0.0, timestamp: 2000 };
      const oneYear = 365 * 24 * 60 * 60;
      engine.accrueInterest(borrowRate, oneYear);

      const debtAfter = engine.getState().debtAmount;
      expect(debtAfter).toBe(debtBefore);
    });
  });

  describe('State Management', () => {
    it('should return state copy, not reference', () => {
      const state1 = engine.getState();
      const state2 = engine.getState();

      expect(state1).not.toBe(state2);
      expect(state1.collateralAmount).toBe(state2.collateralAmount);
    });
  });
});
