import { describe, it, expect, beforeEach } from 'vitest';
import { AuctionSimulator, AuctionConfig } from '../AuctionSimulator';

describe('AuctionSimulator - Happy Path Tests', () => {
  let simulator: AuctionSimulator;

  // Deterministic config for testing
  const testConfig: AuctionConfig = {
    minNoticeTime: 10 * 60, // 10 min
    maxNoticeTime: 60 * 60, // 60 min
    avgAuctionDuration: 40 * 60, // 40 min
    auctionDurationStdDev: 20 * 60, // 20 min
    auctionCreationProbability: 1.0, // 100% for predictable tests
    emergencyThreshold: 1.06061,
    emergencyRebalanceTime: 10 * 60, // 10 min
  };

  beforeEach(() => {
    simulator = new AuctionSimulator(testConfig);
  });

  describe('Within Bounds - No Rebalance', () => {
    it('should NOT rebalance when ratio is within bounds', () => {
      const result = simulator.checkRebalance(
        1000, // timestamp
        1.0625, // ratio (within [1.06135, 1.062893])
        1.06135, // min
        1.062893 // max
      );

      expect(result.shouldRebalance).toBe(false);
      expect(result.direction).toBeUndefined();
    });
  });

  describe('Normal Rebalances', () => {
    it('should eventually trigger DOWN rebalance when below min', () => {
      const ratio = 1.06; // Below min
      const min = 1.06135;
      const max = 1.062893;

      // Start auction process
      simulator.checkRebalance(1000, ratio, min, max);

      // Wait long enough for auction to complete (max notice + max auction)
      const laterTimestamp = 1000 + 200 * 60; // 200 minutes
      const result = simulator.checkRebalance(laterTimestamp, ratio, min, max);

      expect(result.shouldRebalance).toBe(true);
      expect(result.direction).toBe('DOWN');
    });

    it('should eventually trigger UP rebalance when above max', () => {
      const ratio = 1.065; // Above max
      const min = 1.06135;
      const max = 1.062893;

      // Start auction
      simulator.checkRebalance(1000, ratio, min, max);

      // Wait for auction
      const result = simulator.checkRebalance(1000 + 200 * 60, ratio, min, max);

      expect(result.shouldRebalance).toBe(true);
      expect(result.direction).toBe('UP');
    });
  });

  describe('Emergency Rebalances', () => {
    it('should trigger faster when below emergency threshold', () => {
      const ratio = 1.055; // Below emergency threshold
      const min = 1.06135;
      const max = 1.062893;

      // Start emergency
      simulator.checkRebalance(1000, ratio, min, max);

      // Emergency should complete in ~10 min (much faster than normal)
      const result = simulator.checkRebalance(1000 + 15 * 60, ratio, min, max);

      expect(result.shouldRebalance).toBe(true);
      expect(result.direction).toBe('DOWN');
    });
  });

  describe('Reset Functionality', () => {
    it('should reset auction when calling reset()', () => {
      const ratio = 1.06;
      const min = 1.06135;
      const max = 1.062893;

      // Start auction
      simulator.checkRebalance(1000, ratio, min, max);

      // Reset
      simulator.reset();

      // Should be able to start fresh
      const result = simulator.checkRebalance(1000 + 1, ratio, min, max);
      expect(result).toBeDefined(); // No error, clean state
    });
  });

  describe('Probabilistic Behavior', () => {
    it('should create auction immediately with 100% probability', () => {
      // testConfig already has 100% probability
      const ratio = 1.06;
      const min = 1.06135;
      const max = 1.062893;

      // First check should start auction (not shouldRebalance yet, but initiated)
      const result1 = simulator.checkRebalance(1000, ratio, min, max);
      expect(result1.shouldRebalance).toBe(false); // Not ready yet

      // After enough time, should complete
      const result2 = simulator.checkRebalance(1000 + 150 * 60, ratio, min, max);
      expect(result2.shouldRebalance).toBe(true);
    });
  });

  describe('Only One Auction At A Time', () => {
    it('should not start second auction while first is active', () => {
      const ratio = 1.06;
      const min = 1.06135;
      const max = 1.062893;

      // Start first auction
      simulator.checkRebalance(1000, ratio, min, max);

      // Immediately try again (auction still in progress)
      const result = simulator.checkRebalance(1000 + 1, ratio, min, max);

      // Should not have triggered yet
      expect(result.shouldRebalance).toBe(false);
    });
  });
});
