/**
 * Backtester - Runs historical simulations of Leverage Token strategies
 *
 * This class orchestrates the simulation by:
 * 1. Loading historical price data (ETH, weETH, Morpho APY)
 * 2. Initializing a SimulationEngine with strategy config
 * 3. Stepping through time, updating prices and accruing interest
 * 4. Triggering rebalances when needed
 * 5. Calculating performance metrics
 *
 * @see src/simulation/SimulationEngine.ts - Core simulation logic
 */

import { SimulationEngine, SimulationConfig } from './SimulationEngine';
import { MarketPrices, BorrowRate, SimulationMetrics, StateSnapshot, RebalanceResult } from './types';
import { StrategyConfig } from '../types/strategy';
import { AssetData, PricePoint } from '../types/data-sources';

/**
 * Historical data required for backtesting
 */
export interface HistoricalData {
  /** Price data for debt token (e.g., ETH) */
  debtPrices: AssetData;

  /** Price data for collateral token (e.g., weETH) */
  collateralPrices: AssetData;

  /** Borrow APY data from lending protocol */
  borrowAPY: AssetData;
}

/**
 * Configuration for a backtest run
 */
export interface BacktestConfig {
  /** Strategy to backtest */
  strategy: StrategyConfig;

  /** Initial deposit in collateral token (e.g., 1.0 = 1 weETH) */
  initialDepositCollateral: number;

  /** Estimated gas cost per rebalance in USD */
  estimatedRebalanceGasCost: number;

  /** Annual management fee as decimal (e.g., 0.02 = 2% per year) */
  managementFeePercentage: number;
}

/**
 * Result of a backtest run
 */
export interface BacktestResult {
  /** Strategy name */
  strategyName: string;

  /** Start and end timestamps */
  period: {
    start: number;
    end: number;
    durationDays: number;
  };

  /** Performance metrics */
  metrics: SimulationMetrics;

  /** All rebalance operations */
  rebalances: RebalanceResult[];

  /** Historical state snapshots */
  history: StateSnapshot[];
}

export class Backtester {
  private engine: SimulationEngine | null = null;
  private historicalData: HistoricalData | null = null;
  private config: BacktestConfig | null = null;

  /**
   * Load historical data from JSON files
   *
   * @param data Historical price and APY data
   */
  public loadData(data: HistoricalData): void {
    this.historicalData = data;
  }

  /**
   * Initialize the simulation with strategy config
   *
   * @description
   * Sets up the initial state of the leverage token based on:
   * 1. Initial deposit amount
   * 2. Target leverage (calculated from collateral ratios)
   * 3. Initial prices
   *
   * Initial state calculation:
   * - Collateral = initialDeposit
   * - Target ratio determines leverage
   * - Debt = Collateral * (targetRatio - 1) / targetRatio
   * - Shares = initialDeposit (1:1 on first deposit)
   *
   * Example for 17x leverage (target ratio 1.0625):
   * - Deposit: 1 weETH
   * - Collateral: 17 weETH (after leverage)
   * - Debt: 16 WETH
   * - Shares: 1 (representing equity of 1 weETH)
   *
   * @param config Backtest configuration
   */
  public initialize(config: BacktestConfig): void {
    if (!this.historicalData) {
      throw new Error('Historical data not loaded. Call loadData() first.');
    }

    this.config = config;

    const { strategy, initialDepositCollateral, estimatedRebalanceGasCost } = config;

    // Get initial prices from backtest range (not full data range)
    const backtestRange = strategy.timeRangeBacktest;
    const firstDebtPrice = this.historicalData.debtPrices.data.find(p => p.timestamp >= backtestRange.from);
    const firstCollateralPrice = this.historicalData.collateralPrices.data.find(p => p.timestamp >= backtestRange.from);

    if (!firstDebtPrice || !firstCollateralPrice) {
      throw new Error('No price data available for backtest range');
    }

    // Calculate initial state based on target leverage
    // IMPORTANT: Must use USD values to get correct collateral ratio!
    //
    // Given:
    // - Initial deposit: X weETH
    // - Target collateral ratio: R (e.g., 1.0625)
    // - Initial prices: P_weETH, P_ETH
    //
    // The collateral ratio formula is:
    //   R = (collateral_amount * P_weETH) / (debt_amount * P_ETH)
    //
    // Equity formula:
    //   equity = collateral_amount - (debt_amount * P_ETH / P_weETH)
    //
    // From target ratio:
    //   collateral_amount = R * debt_amount * P_ETH / P_weETH
    //
    // Substitute into equity:
    //   equity = R * debt_amount * P_ETH / P_weETH - debt_amount * P_ETH / P_weETH
    //   equity = debt_amount * P_ETH / P_weETH * (R - 1)
    //
    // Solving for debt_amount:
    //   debt_amount = equity * P_weETH / (P_ETH * (R - 1))
    //
    // And collateral_amount:
    //   collateral_amount = R * debt_amount * P_ETH / P_weETH

    const targetRatio = strategy.collateralRatios.target;
    const equityCollateral = initialDepositCollateral;

    const collateralPriceUSD = firstCollateralPrice.price;
    const debtPriceUSD = firstDebtPrice.price;

    // Calculate debt amount in debt token units
    const debtAmount = equityCollateral * collateralPriceUSD / (debtPriceUSD * (targetRatio - 1));

    // Calculate collateral amount in collateral token units
    const collateralAmount = targetRatio * debtAmount * debtPriceUSD / collateralPriceUSD;

    // Convert to token amounts (assume 18 decimals)
    const DECIMALS = 1e18;
    const initialCollateral = BigInt(Math.floor(collateralAmount * DECIMALS));
    const initialDebt = BigInt(Math.floor(debtAmount * DECIMALS));
    const initialShares = BigInt(Math.floor(equityCollateral * DECIMALS));

    const simulationConfig: SimulationConfig = {
      initialCollateral,
      initialDebt,
      initialShares,
      collateralRatios: strategy.collateralRatios,
      startTimestamp: firstDebtPrice.timestamp,
      estimatedRebalanceGasCost,
      managementFeePercentage: config.managementFeePercentage,
    };

    this.engine = new SimulationEngine(simulationConfig);

    console.log(`\n🎬 Initialized simulation for ${strategy.name}`);
    console.log(`   Initial deposit: ${initialDepositCollateral} ${strategy.collateral.symbol}`);
    console.log(`   Target leverage: ${(1 / (1 - 1/targetRatio)).toFixed(2)}x`);
    console.log(`   Initial collateral: ${Number(initialCollateral) / DECIMALS} ${strategy.collateral.symbol}`);
    console.log(`   Initial debt: ${Number(initialDebt) / DECIMALS} ${strategy.debt.symbol}`);
    console.log(`   Initial shares: ${Number(initialShares) / DECIMALS}\n`);
  }

  /**
   * Run the backtest simulation
   *
   * @description
   * Steps through historical data chronologically:
   * 1. Update market prices
   * 2. Accrue interest on debt
   * 3. Check if rebalance needed
   * 4. Execute rebalance if needed
   * 5. Record state snapshot
   *
   * @returns Backtest results with metrics and history
   */
  public async run(): Promise<BacktestResult> {
    if (!this.engine || !this.historicalData || !this.config) {
      throw new Error('Backtester not initialized. Call initialize() first.');
    }

    console.log(`🚀 Running backtest...\n`);

    const { debtPrices, collateralPrices, borrowAPY } = this.historicalData;
    const rebalances: RebalanceResult[] = [];

    // Filter data to backtest range
    const backtestRange = this.config.strategy.timeRangeBacktest;
    const filteredDebtPrices = debtPrices.data.filter(p => p.timestamp >= backtestRange.from && p.timestamp <= backtestRange.to);
    const filteredCollateralPrices = collateralPrices.data.filter(p => p.timestamp >= backtestRange.from && p.timestamp <= backtestRange.to);
    const filteredBorrowAPY = borrowAPY.data.filter(p => p.timestamp >= backtestRange.from && p.timestamp <= backtestRange.to);

    console.log(`📊 Backtest range: ${new Date(backtestRange.from * 1000).toISOString().split('T')[0]} → ${new Date(backtestRange.to * 1000).toISOString().split('T')[0]}`);

    // Merge and sort all data points by timestamp
    const timeline = this.mergeTimelines(filteredDebtPrices, filteredCollateralPrices, filteredBorrowAPY);

    // Note: We keep 5-minute granularity to accurately simulate auction timing.
    // The AuctionSimulator module handles the realistic delays for rebalances.

    console.log(`📊 Processing ${timeline.length} time points...`);

    let lastTimestamp = timeline[0]?.timestamp || 0;
    let progressCounter = 0;
    const progressInterval = Math.floor(timeline.length / 20); // Show progress every 5%

    for (const point of timeline) {
      const timeDelta = point.timestamp - lastTimestamp;

      // Get current prices and APY
      const prices: MarketPrices = {
        collateralPriceUSD: point.collateralPrice,
        debtPriceUSD: point.debtPrice,
        timestamp: point.timestamp,
      };

      const borrowRate: BorrowRate = {
        apy: point.borrowAPY,
        timestamp: point.timestamp,
      };

      // 1. Accrue management fee (dilutes shares)
      this.engine.accrueManagementFee(point.timestamp);

      // 2. Accrue interest on debt
      if (timeDelta > 0) {
        this.engine.accrueInterest(borrowRate, timeDelta);
      }

      // 3. Update timestamp
      this.engine.updateTimestamp(point.timestamp);

      // 4. Check if rebalance needed
      const rebalanceCheck = this.engine.checkRebalanceNeeded(prices);
      if (rebalanceCheck.needed && rebalanceCheck.direction) {
        const result = this.engine.rebalance(prices, rebalanceCheck.direction);
        rebalances.push(result);
      }

      // 5. Record snapshot
      this.engine.recordSnapshot(prices, borrowRate.apy);

      lastTimestamp = point.timestamp;

      // Progress indicator
      progressCounter++;
      if (progressCounter % progressInterval === 0) {
        const percent = Math.floor((progressCounter / timeline.length) * 100);
        process.stdout.write(`\r   Progress: ${percent}%`);
      }
    }

    console.log(`\r   Progress: 100% ✓\n`);
    console.log(`🔄 Executed ${rebalances.length} rebalances\n`);

    // Calculate metrics
    const metrics = this.calculateMetrics(this.engine.getHistory(), rebalances);

    const result: BacktestResult = {
      strategyName: this.config.strategy.name,
      period: {
        start: timeline[0]?.timestamp || 0,
        end: timeline[timeline.length - 1]?.timestamp || 0,
        durationDays: ((timeline[timeline.length - 1]?.timestamp || 0) - (timeline[0]?.timestamp || 0)) / 86400,
      },
      metrics,
      rebalances,
      history: this.engine.getHistory(),
    };

    return result;
  }

  /**
   * Merge multiple price timelines into a single sorted timeline
   *
   * @description
   * Combines debt prices, collateral prices, and APY data.
   * Uses forward-fill for missing values (last known value).
   */
  private mergeTimelines(
    debtPrices: PricePoint[],
    collateralPrices: PricePoint[],
    apyData: PricePoint[]
  ): Array<{
    timestamp: number;
    debtPrice: number;
    collateralPrice: number;
    borrowAPY: number;
  }> {
    // Create maps for fast lookup
    const debtMap = new Map(debtPrices.map(p => [p.timestamp, p.price]));
    const collateralMap = new Map(collateralPrices.map(p => [p.timestamp, p.price]));
    const apyMap = new Map(apyData.map(p => [p.timestamp, p.price]));

    // Get all unique timestamps
    const allTimestamps = new Set([
      ...debtPrices.map(p => p.timestamp),
      ...collateralPrices.map(p => p.timestamp),
      ...apyData.map(p => p.timestamp),
    ]);

    const sortedTimestamps = Array.from(allTimestamps).sort((a, b) => a - b);

    // Forward-fill missing values
    let lastDebtPrice = 0;
    let lastCollateralPrice = 0;
    let lastAPY = 0;

    const timeline = sortedTimestamps.map(timestamp => {
      const debtPrice = debtMap.get(timestamp) || lastDebtPrice;
      const collateralPrice = collateralMap.get(timestamp) || lastCollateralPrice;
      const borrowAPY = apyMap.get(timestamp) || lastAPY;

      lastDebtPrice = debtPrice;
      lastCollateralPrice = collateralPrice;
      lastAPY = borrowAPY;

      return { timestamp, debtPrice, collateralPrice, borrowAPY };
    });

    return timeline;
  }

  /**
   * Calculate performance metrics from simulation history
   */
  private calculateMetrics(history: StateSnapshot[], rebalances: RebalanceResult[]): SimulationMetrics {
    if (history.length === 0) {
      throw new Error('No history to calculate metrics');
    }

    const first = history[0]!;
    const last = history[history.length - 1]!;

    const initialSharePrice = first.sharePrice;
    const finalSharePrice = last.sharePrice;
    const totalReturn = ((finalSharePrice - initialSharePrice) / initialSharePrice) * 100;

    const durationYears = (last.timestamp - first.timestamp) / (365.25 * 24 * 60 * 60);
    const annualizedReturn = (Math.pow(finalSharePrice / initialSharePrice, 1 / durationYears) - 1) * 100;

    // Calculate max drawdown
    let peak = initialSharePrice;
    let maxDrawdown = 0;

    for (const snapshot of history) {
      if (snapshot.sharePrice > peak) {
        peak = snapshot.sharePrice;
      }
      const drawdown = ((peak - snapshot.sharePrice) / peak) * 100;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }

    // Calculate avg collateral ratio
    const avgCollateralRatio = history.reduce((sum, s) => sum + s.collateralRatio, 0) / history.length;

    // Calculate time outside bounds
    const timesBelowMin = history.filter(s => s.collateralRatio < this.config!.strategy.collateralRatios.min).length;
    const timesAboveMax = history.filter(s => s.collateralRatio > this.config!.strategy.collateralRatios.max).length;

    // Calculate total gas costs
    const totalGasCostsUSD = rebalances.reduce((sum, r) => sum + r.estimatedGasCostUSD, 0);

    return {
      initialSharePrice,
      finalSharePrice,
      totalReturn,
      annualizedReturn,
      maxDrawdown,
      rebalanceCount: rebalances.length,
      totalGasCostsUSD,
      avgCollateralRatio,
      timesBelowMin,
      timesAboveMax,
    };
  }
}
