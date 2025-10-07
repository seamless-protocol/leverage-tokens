/**
 * Auction Simulator Module
 *
 * Simulates the realistic timing and probability of rebalances via Dutch Auctions
 * instead of assuming instant, deterministic rebalancing.
 */

export interface AuctionConfig {
  /** Minimum time for auction to be noticed and created (seconds) */
  minNoticeTime: number;

  /** Maximum time for auction to be noticed and created (seconds) */
  maxNoticeTime: number;

  /** Average time for auction to execute after creation (seconds) */
  avgAuctionDuration: number;

  /** Standard deviation for auction execution time (seconds) */
  auctionDurationStdDev: number;

  /** Probability that someone notices and creates auction when out of bounds (0-1) */
  auctionCreationProbability: number;

  /** Emergency threshold - below this ratio, rebalance happens fast regardless */
  emergencyThreshold: number;

  /** Time for emergency rebalance (much faster than normal auction) */
  emergencyRebalanceTime: number;
}

export const DEFAULT_AUCTION_CONFIG: AuctionConfig = {
  minNoticeTime: 600,           // 10 minutes minimum to notice
  maxNoticeTime: 3600,          // 60 minutes maximum to notice
  avgAuctionDuration: 2400,     // 40 minutes average auction duration
  auctionDurationStdDev: 1200,  // 20 minutes std deviation
  auctionCreationProbability: 0.05, // 5% chance someone creates auction per 5-min check (realistic for tight bounds)
  emergencyThreshold: 1.06061,  // Pre-liquidation threshold from deploy script
  emergencyRebalanceTime: 600,  // 10 minutes for emergency rebalance
};

/**
 * State of an ongoing auction
 */
interface AuctionState {
  /** When the auction was created */
  createdAt: number;

  /** When the auction is expected to execute */
  executeAt: number;

  /** Direction of rebalance */
  direction: 'UP' | 'DOWN';

  /** Whether this is an emergency rebalance */
  isEmergency: boolean;
}

/**
 * Simulates Dutch Auction timing and probability for rebalances
 */
export class AuctionSimulator {
  private config: AuctionConfig;
  private activeAuction: AuctionState | null = null;

  constructor(config: Partial<AuctionConfig> = {}) {
    this.config = { ...DEFAULT_AUCTION_CONFIG, ...config };
  }

  /**
   * Check if a rebalance should be triggered based on auction simulation
   *
   * @param currentTimestamp Current simulation timestamp
   * @param currentRatio Current collateral ratio
   * @param minRatio Minimum allowed ratio
   * @param maxRatio Maximum allowed ratio
   * @returns Object with shouldRebalance flag and direction
   */
  public checkRebalance(
    currentTimestamp: number,
    currentRatio: number,
    minRatio: number,
    maxRatio: number
  ): { shouldRebalance: boolean; direction?: 'UP' | 'DOWN'; isEmergency?: boolean } {
    // Check if there's an active auction ready to execute
    if (this.activeAuction) {
      if (currentTimestamp >= this.activeAuction.executeAt) {
        // Auction is ready to execute
        const result = {
          shouldRebalance: true,
          direction: this.activeAuction.direction,
          isEmergency: this.activeAuction.isEmergency,
        };

        // Clear the auction after execution
        this.activeAuction = null;

        return result;
      }

      // Auction is in progress, wait
      return { shouldRebalance: false };
    }

    // Check if ratio is within bounds
    const isInBounds = currentRatio >= minRatio && currentRatio <= maxRatio;
    if (isInBounds) {
      return { shouldRebalance: false };
    }

    // Ratio is out of bounds
    const direction: 'UP' | 'DOWN' = currentRatio < minRatio ? 'DOWN' : 'UP';

    // Check for emergency (pre-liquidation threshold)
    const isEmergency = currentRatio < this.config.emergencyThreshold;

    if (isEmergency) {
      // Emergency: create auction immediately with short duration
      this.activeAuction = {
        createdAt: currentTimestamp,
        executeAt: currentTimestamp + this.config.emergencyRebalanceTime,
        direction,
        isEmergency: true,
      };

      return { shouldRebalance: false }; // Will execute on next check after emergency time
    }

    // Normal case: probabilistic auction creation
    const shouldCreateAuction = Math.random() < this.config.auctionCreationProbability;

    if (shouldCreateAuction) {
      // Someone noticed and decided to create an auction
      const noticeTime = this.randomBetween(this.config.minNoticeTime, this.config.maxNoticeTime);
      const auctionDuration = this.randomNormal(this.config.avgAuctionDuration, this.config.auctionDurationStdDev);

      this.activeAuction = {
        createdAt: currentTimestamp,
        executeAt: currentTimestamp + noticeTime + Math.max(0, auctionDuration),
        direction,
        isEmergency: false,
      };
    }

    return { shouldRebalance: false };
  }

  /**
   * Reset auction state (e.g., when ratio returns to bounds)
   */
  public reset(): void {
    this.activeAuction = null;
  }

  /**
   * Get info about active auction (for debugging)
   */
  public getAuctionInfo(): AuctionState | null {
    return this.activeAuction;
  }

  /**
   * Generate random number between min and max (uniform distribution)
   */
  private randomBetween(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }

  /**
   * Generate random number with normal distribution using Box-Muller transform
   */
  private randomNormal(mean: number, stdDev: number): number {
    // Box-Muller transform
    const u1 = Math.random();
    const u2 = Math.random();
    const z0 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math.PI * u2);
    return mean + z0 * stdDev;
  }
}
