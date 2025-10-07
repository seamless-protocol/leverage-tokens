/**
 * SimulationEngine - Core simulation logic for Leverage Token backtesting
 *
 * This engine replicates the behavior of the Seamless Leverage Token protocol
 * without requiring blockchain interaction. It maintains state and applies
 * operations based on the same formulas used in the smart contracts.
 *
 * @see src/LeverageManager.sol - On-chain manager implementation
 * @see src/LeverageToken.sol - ERC20 token implementation
 * @see src/lending/MorphoLendingAdapter.sol - Lending integration
 */

import {
  LeverageTokenState,
  CollateralRatioConfig,
  MarketPrices,
  BorrowRate,
  RebalanceResult,
  StateSnapshot,
} from './types';
import { AuctionSimulator, AuctionConfig, DEFAULT_AUCTION_CONFIG } from './AuctionSimulator';

/**
 * Configuration for initializing a Leverage Token simulation
 */
export interface SimulationConfig {
  /** Initial collateral amount (e.g., 1 weETH = 1e18) */
  initialCollateral: bigint;

  /** Initial debt amount (e.g., 16 WETH = 16e18 for 17x leverage) */
  initialDebt: bigint;

  /** Initial shares to mint (e.g., 1e18) */
  initialShares: bigint;

  /** Collateral ratio bounds (includes preLiquidationThreshold for emergency rebalances) */
  collateralRatios: CollateralRatioConfig;

  /** Starting timestamp (Unix seconds) */
  startTimestamp: number;

  /** Estimated gas cost per rebalance in USD */
  estimatedRebalanceGasCost: number;

  /** Annual management fee as decimal (e.g., 0.02 = 2% per year) */
  managementFeePercentage: number;
}

export class SimulationEngine {
  private state: LeverageTokenState;
  private config: CollateralRatioConfig;
  private estimatedRebalanceGasCost: number;
  private managementFeePercentage: number;
  private lastFeeAccrualTimestamp: number;
  private history: StateSnapshot[] = [];

  // Auction simulator for realistic rebalance timing
  private auctionSimulator: AuctionSimulator;

  constructor(config: SimulationConfig) {
    this.state = {
      collateralAmount: config.initialCollateral,
      debtAmount: config.initialDebt,
      totalShares: config.initialShares,
      timestamp: config.startTimestamp,
    };

    this.config = config.collateralRatios;
    this.estimatedRebalanceGasCost = config.estimatedRebalanceGasCost;
    this.managementFeePercentage = config.managementFeePercentage;
    this.lastFeeAccrualTimestamp = config.startTimestamp; // Start accruing from beginning

    // Initialize auction simulator with emergency threshold from config
    this.auctionSimulator = new AuctionSimulator({
      ...DEFAULT_AUCTION_CONFIG,
      emergencyThreshold: config.collateralRatios.preLiquidationThreshold,
    });
  }

  /**
   * Get current state of the leverage token
   */
  public getState(): LeverageTokenState {
    return { ...this.state };
  }

  /**
   * Get full history of state snapshots
   */
  public getHistory(): StateSnapshot[] {
    return [...this.history];
  }

  /**
   * Calculate current collateral ratio
   *
   * @description
   * Collateral Ratio = (Collateral Value in USD) / (Debt Value in USD)
   *
   * Formula from protocol:
   * ratio = (collateralAmount * collateralPriceUSD) / (debtAmount * debtPriceUSD)
   *
   * @reference src/lending/MorphoLendingAdapter.sol::getCollateralRatio()
   *
   * @param prices Current market prices
   * @returns Collateral ratio as decimal (e.g., 1.0625)
   */
  public calculateCollateralRatio(prices: MarketPrices): number {
    if (this.state.debtAmount === 0n) {
      // No debt means infinite collateral ratio (safe)
      return Infinity;
    }

    // Convert bigint to number for calculation
    // Note: In production, use precise decimal libraries like decimal.js
    const collateralValue = Number(this.state.collateralAmount) / 1e18 * prices.collateralPriceUSD;
    const debtValue = Number(this.state.debtAmount) / 1e18 * prices.debtPriceUSD;

    return collateralValue / debtValue;
  }

  /**
   * Calculate share price in collateral token terms
   *
   * @description
   * Share Price = Equity / Total Shares
   * Equity = Collateral Value - Debt Value (in collateral token units)
   *
   * Formula from protocol:
   * sharePrice = (collateral - debt * debtPrice / collateralPrice) / totalShares
   *
   * This follows ERC-4626 vault logic: shares represent claim to equity.
   *
   * @reference src/interfaces/ILeverageToken.sol::convertToAssets()
   * @reference src/LeverageManager.sol::convertToAssets() (lines 194-208)
   *
   * @param prices Current market prices
   * @returns Share price in collateral token units
   */
  public calculateSharePrice(prices: MarketPrices): number {
    if (this.state.totalShares === 0n) {
      return 0;
    }

    // Calculate equity in collateral token units
    // equity = collateral - (debt * debtPrice / collateralPrice)
    const collateralNum = Number(this.state.collateralAmount) / 1e18;
    const debtNum = Number(this.state.debtAmount) / 1e18;
    const debtInCollateralUnits = debtNum * (prices.debtPriceUSD / prices.collateralPriceUSD);

    const equityInCollateral = collateralNum - debtInCollateralUnits;

    // sharePrice = equity / totalShares
    const sharesNum = Number(this.state.totalShares) / 1e18;

    return equityInCollateral / sharesNum;
  }

  /**
   * Calculate total equity in USD
   *
   * @description
   * Equity = Collateral Value - Debt Value
   *
   * @param prices Current market prices
   * @returns Equity in USD
   */
  public calculateEquityUSD(prices: MarketPrices): number {
    const collateralValue = Number(this.state.collateralAmount) / 1e18 * prices.collateralPriceUSD;
    const debtValue = Number(this.state.debtAmount) / 1e18 * prices.debtPriceUSD;

    return collateralValue - debtValue;
  }

  /**
   * Accrue management fee by diluting shares
   *
   * @description
   * Management fee accrues linearly over time by minting new shares to the treasury.
   * This dilutes existing shareholders proportionally.
   *
   * Formula from protocol (FeeManager.sol::_getAccruedManagementFee):
   * sharesFee = (managementFee * totalSupply * duration) / (MAX_BPS * SECS_PER_YEAR)
   *
   * Where:
   * - managementFee: Annual fee in basis points (e.g., 200 = 2%)
   * - duration: Time elapsed in seconds
   * - MAX_BPS: 10000 (100%)
   * - SECS_PER_YEAR: 31536000
   *
   * Effect on share price:
   * - New shares are minted to treasury
   * - Total shares increases
   * - Share price = equity / (totalShares + feeShares)
   * - This effectively reduces share price for holders
   *
   * @reference src/FeeManager.sol::_getAccruedManagementFee() (lines 256-277)
   * @reference src/FeeManager.sol::chargeManagementFee() (lines 149-164)
   *
   * @param currentTimestamp Current timestamp (Unix seconds)
   */
  public accrueManagementFee(currentTimestamp: number): void {
    if (this.managementFeePercentage === 0) {
      return;
    }

    const timeElapsed = currentTimestamp - this.lastFeeAccrualTimestamp;

    if (timeElapsed <= 0) {
      return;
    }

    const SECONDS_PER_YEAR = 365.25 * 24 * 60 * 60;

    // Calculate shares to mint as fee
    // feeShares = totalSupply * (managementFee * timeElapsed / SECONDS_PER_YEAR)
    const totalSupplyNum = Number(this.state.totalShares);
    const feeMultiplier = (this.managementFeePercentage * timeElapsed) / SECONDS_PER_YEAR;
    const feeShares = totalSupplyNum * feeMultiplier;

    // Mint fee shares (dilutes existing holders)
    this.state.totalShares = this.state.totalShares + BigInt(Math.floor(feeShares));
    this.lastFeeAccrualTimestamp = currentTimestamp;
  }

  /**
   * Accrue interest on debt based on borrow APY
   *
   * @description
   * Interest accrues continuously on the debt position.
   * For small time intervals, we use linear approximation:
   *
   * newDebt = debt * (1 + apy * timeDelta / SECONDS_PER_YEAR)
   *
   * Where:
   * - apy: Annual Percentage Yield (as decimal, e.g., 0.025 = 2.5%)
   * - timeDelta: Time elapsed in seconds
   * - SECONDS_PER_YEAR: 365.25 * 24 * 60 * 60 = 31557600
   *
   * This happens automatically in the lending protocol (Morpho Blue).
   *
   * @reference src/lending/MorphoLendingAdapter.sol::getDebt()
   * @reference Morpho Blue's interest rate model
   *
   * @param borrowRate Current borrow rate
   * @param timeDelta Time elapsed since last update (seconds)
   */
  public accrueInterest(borrowRate: BorrowRate, timeDelta: number): void {
    if (timeDelta <= 0 || this.state.debtAmount === 0n) {
      return;
    }

    const SECONDS_PER_YEAR = 365.25 * 24 * 60 * 60;

    // Calculate interest multiplier: (1 + apy * timeDelta / SECONDS_PER_YEAR)
    const interestMultiplier = 1 + (borrowRate.apy * timeDelta) / SECONDS_PER_YEAR;

    // Apply interest to debt
    const debtNum = Number(this.state.debtAmount);
    const newDebt = BigInt(Math.floor(debtNum * interestMultiplier));

    this.state.debtAmount = newDebt;
    this.state.timestamp = borrowRate.timestamp;
  }

  /**
   * Check if rebalance is needed based on collateral ratio
   *
   * @description
   * Rebalance is triggered when:
   * - ratio < min: Position is too risky (approaching liquidation)
   * - ratio > max: Position is under-leveraged (not maximizing returns)
   *
   * Additionally, rebalances are rate-limited by minRebalanceInterval to simulate
   * realistic bot behavior and prevent excessive rebalancing costs.
   *
   * @reference src/rebalance/CollateralRatiosRebalanceAdapter.sol
   *
   * @param prices Current market prices
   * @returns Object with needsRebalance flag and direction
   */
  public checkRebalanceNeeded(prices: MarketPrices): {
    needed: boolean;
    direction?: 'UP' | 'DOWN';
    currentRatio: number;
  } {
    const ratio = this.calculateCollateralRatio(prices);

    // Use auction simulator to determine if rebalance should happen
    // This simulates:
    // - Probabilistic auction creation (not everyone notices immediately)
    // - Auction duration (time for arbitrageurs to execute)
    // - Emergency fast-track for pre-liquidation scenarios
    const auctionResult = this.auctionSimulator.checkRebalance(
      prices.timestamp,
      ratio,
      this.config.min,
      this.config.max
    );

    // If ratio is back in bounds, reset auction state
    if (ratio >= this.config.min && ratio <= this.config.max) {
      this.auctionSimulator.reset();
    }

    const result: { needed: boolean; direction?: 'UP' | 'DOWN'; currentRatio: number } = {
      needed: auctionResult.shouldRebalance,
      currentRatio: ratio,
    };

    if (auctionResult.direction) {
      result.direction = auctionResult.direction;
    }

    return result;
  }

  /**
   * Execute a rebalance operation
   *
   * @description
   * Rebalancing adjusts the collateral/debt ratio back to the target ratio.
   *
   * REBALANCE DOWN (ratio too low):
   * 1. Withdraw collateral from lending pool
   * 2. Swap collateral → debt (at current market prices)
   * 3. Repay debt to lending pool
   * Result: Less collateral, less debt, ratio increases to target
   *
   * REBALANCE UP (ratio too high):
   * 1. Borrow more debt from lending pool
   * 2. Swap debt → collateral (at current market prices)
   * 3. Deposit collateral to lending pool
   * Result: More collateral, more debt, ratio decreases to target
   *
   * Formula to reach target ratio:
   * targetRatio = collateralValue / debtValue
   * If rebalancing DOWN: reduce both proportionally
   * If rebalancing UP: increase both proportionally
   *
   * Simplified calculation:
   * targetCollateral = targetRatio * debtValue / collateralPrice
   * targetDebt = collateralValue / targetRatio / debtPrice
   *
   * @reference src/interfaces/ILeverageManager.sol::rebalance() (lines 313-333)
   * @reference src/rebalance/RebalanceAdapter.sol
   * @reference src/rebalance/CollateralRatiosRebalanceAdapter.sol
   *
   * @param prices Current market prices for swaps
   * @param direction Direction to rebalance ('UP' or 'DOWN')
   * @returns RebalanceResult with before/after state
   */
  public rebalance(prices: MarketPrices, direction: 'UP' | 'DOWN'): RebalanceResult {
    const stateBefore = { ...this.state };
    const ratioBefore = this.calculateCollateralRatio(prices);

    // Rebalancing preserves total value while adjusting the ratio
    // Total value in debt terms = debt + (collateral * collateralPrice / debtPrice)
    const totalValueInDebtTerms = Number(this.state.debtAmount) / 1e18 +
      (Number(this.state.collateralAmount) / 1e18 * prices.collateralPriceUSD / prices.debtPriceUSD);

    // Calculate target amounts that preserve total value and achieve target ratio
    // Solving: totalValue = targetDebt + targetCollateral * P_c / P_d
    //          AND ratio = targetCollateral * P_c / (targetDebt * P_d) = target
    // Result: targetDebt = totalValue / (1 + target)

    const targetDebtAmount = totalValueInDebtTerms / (1 + this.config.target);
    const targetCollateralAmount = targetDebtAmount * this.config.target * prices.debtPriceUSD / prices.collateralPriceUSD;

    // NOTE: In the real protocol, the vault does NOT pay for swap slippage or DEX fees.
    // The rebalancer (external bot) performs the swap externally and absorbs those costs.
    // The vault only does lending operations (addCollateral, borrow, repay, removeCollateral).
    //
    // The only costs that affect the vault's share price are:
    // 1. Management fees (dilutes shares)
    // 2. Borrow interest (debt grows)
    // 3. Mint/Redeem fees (one-time cost when users enter/exit)

    const targetDebt = BigInt(Math.floor(targetDebtAmount * 1e18));
    const targetCollateral = BigInt(Math.floor(targetCollateralAmount * 1e18));

    // Update state to target values
    this.state.collateralAmount = targetCollateral;
    this.state.debtAmount = targetDebt;
    this.state.timestamp = prices.timestamp;

    // Reset auction simulator after successful rebalance
    this.auctionSimulator.reset();

    const stateAfter = { ...this.state };
    const ratioAfter = this.calculateCollateralRatio(prices);

    return {
      stateBefore,
      stateAfter,
      direction,
      ratioBefore,
      ratioAfter,
      estimatedGasCostUSD: this.estimatedRebalanceGasCost,
    };
  }

  /**
   * Record a state snapshot for historical tracking
   *
   * @param prices Current market prices
   * @param borrowAPY Current borrow APY
   */
  public recordSnapshot(prices: MarketPrices, borrowAPY: number): void {
    const snapshot: StateSnapshot = {
      timestamp: this.state.timestamp,
      state: { ...this.state },
      prices,
      borrowAPY,
      collateralRatio: this.calculateCollateralRatio(prices),
      sharePrice: this.calculateSharePrice(prices),
      equityUSD: this.calculateEquityUSD(prices),
    };

    this.history.push(snapshot);
  }

  /**
   * Update timestamp (for advancing simulation time)
   */
  public updateTimestamp(timestamp: number): void {
    this.state.timestamp = timestamp;
  }
}
