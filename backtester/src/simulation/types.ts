/**
 * Simulation types for Leverage Token backtesting
 *
 * These types replicate the on-chain state and behavior of Leverage Tokens
 * as defined in the Seamless Leverage Token protocol.
 *
 * @see src/types/DataTypes.sol - Original Solidity struct definitions
 * @see src/interfaces/ILeverageManager.sol - Manager interface
 */

/**
 * Represents the complete state of a Leverage Token at any point in time
 *
 * @description
 * A Leverage Token maintains a leveraged position by:
 * 1. Holding collateral (e.g., weETH) in a lending protocol (e.g., Morpho Blue)
 * 2. Borrowing debt (e.g., WETH) against that collateral
 * 3. Issuing shares (ERC20 tokens) representing claim to the equity
 *
 * Equity = Collateral Value - Debt Value (denominated in debt asset)
 *
 * @reference src/types/DataTypes.sol::LeverageTokenState
 * @reference src/LeverageToken.sol - ERC20 token implementation
 */
export interface LeverageTokenState {
  /**
   * Amount of collateral held in the lending protocol (e.g., weETH)
   * Native units (e.g., 1e18 for 18 decimals)
   */
  collateralAmount: bigint;

  /**
   * Amount of debt owed to the lending protocol (e.g., WETH)
   * Native units (e.g., 1e18 for 18 decimals)
   */
  debtAmount: bigint;

  /**
   * Total shares (ERC20 tokens) representing claims to equity
   * Native units (e.g., 1e18 for 18 decimals)
   *
   * @see src/LeverageToken.sol::totalSupply()
   */
  totalShares: bigint;

  /**
   * Current timestamp of this state (Unix seconds)
   */
  timestamp: number;
}

/**
 * Configuration for collateral ratio bounds and target
 *
 * @description
 * The protocol maintains the collateral ratio within these bounds:
 * - If ratio < min: Rebalance DOWN (sell collateral, repay debt)
 * - If ratio > max: Rebalance UP (borrow more, buy collateral)
 * - Target: Desired ratio after rebalance
 *
 * Collateral Ratio = (Collateral Value in USD) / (Debt Value in USD)
 *
 * @example
 * For weETH-WETH-17x:
 * - min: 1.06135 (94.2% LTV)
 * - target: 1.0625 (94.1% LTV)
 * - max: 1.062893 (94.08% LTV)
 * - preLiquidationThreshold: 1.06061 (94.28% LTV) - emergency fast-track
 *
 * @reference script/8453/CreateLeverageToken.WEETH-WETH-17x.s.sol::collateralRatios
 * @reference src/rebalance/CollateralRatiosRebalanceAdapter.sol
 * @reference src/rebalance/PreLiquidationRebalanceAdapter.sol
 */
export interface CollateralRatioConfig {
  /** Minimum allowed collateral ratio (triggers rebalance down if below) */
  min: number;

  /** Target collateral ratio (goal after rebalance) */
  target: number;

  /** Maximum allowed collateral ratio (triggers rebalance up if above) */
  max: number;

  /** Pre-liquidation threshold for emergency rebalances (below min, allows fast-track) */
  preLiquidationThreshold: number;
}

/**
 * Market prices at a specific point in time
 *
 * @description
 * Prices are denominated in USD to allow ratio calculations.
 * The protocol uses oracles for these prices on-chain.
 *
 * @reference src/periphery/PricingAdapter.sol - On-chain oracle integration
 */
export interface MarketPrices {
  /** Price of collateral token in USD (e.g., weETH price) */
  collateralPriceUSD: number;

  /** Price of debt token in USD (e.g., WETH price) */
  debtPriceUSD: number;

  /** Timestamp of these prices (Unix seconds) */
  timestamp: number;
}

/**
 * Borrow rate from the lending protocol at a specific point in time
 *
 * @description
 * The borrow APY is the interest rate charged on debt.
 * This comes from the underlying lending protocol (e.g., Morpho Blue).
 *
 * Interest accrues continuously: debt(t) = debt(0) * e^(apy * time)
 * Simplified: debt(t+Δt) ≈ debt(t) * (1 + apy * Δt)
 *
 * @reference src/lending/MorphoLendingAdapter.sol - Morpho integration
 */
export interface BorrowRate {
  /** Annual Percentage Yield (APY) as decimal (e.g., 0.025 = 2.5%) */
  apy: number;

  /** Timestamp of this rate (Unix seconds) */
  timestamp: number;
}

/**
 * Result of a rebalance operation
 *
 * @description
 * Rebalancing adjusts the collateral/debt ratio back to target.
 * This can happen in two directions:
 *
 * 1. REBALANCE DOWN (ratio too low, position too risky):
 *    - Withdraw collateral from lending pool
 *    - Swap collateral → debt
 *    - Repay debt
 *
 * 2. REBALANCE UP (ratio too high, position under-leveraged):
 *    - Borrow more debt
 *    - Swap debt → collateral
 *    - Deposit collateral to lending pool
 *
 * @reference src/interfaces/ILeverageManager.sol::rebalance()
 * @reference src/rebalance/RebalanceAdapter.sol
 */
export interface RebalanceResult {
  /** State before rebalance */
  stateBefore: LeverageTokenState;

  /** State after rebalance */
  stateAfter: LeverageTokenState;

  /** Direction of rebalance */
  direction: 'UP' | 'DOWN';

  /** Collateral ratio before rebalance */
  ratioBefore: number;

  /** Collateral ratio after rebalance */
  ratioAfter: number;

  /** Estimated gas cost in USD (for tracking costs) */
  // TODO: not accurate
  estimatedGasCostUSD: number;
}

/**
 * Performance metrics for a simulation run
 *
 * @description
 * These metrics help evaluate the performance of a leverage token
 * strategy over the backtesting period.
 */
export interface SimulationMetrics {
  /** Starting share price (in collateral token) */
  initialSharePrice: number;

  /** Ending share price (in collateral token) */
  finalSharePrice: number;

  /** Total return percentage */
  totalReturn: number;

  /** Annualized return percentage */
  annualizedReturn: number;

  /** Maximum drawdown from peak */
  maxDrawdown: number;

  /** Number of rebalance operations */
  rebalanceCount: number;

  /** Total estimated gas costs in USD */
  totalGasCostsUSD: number;

  /** Average collateral ratio maintained */
  avgCollateralRatio: number;

  /** Time spent below min collateral ratio (seconds) */
  timesBelowMin: number;

  /** Time spent above max collateral ratio (seconds) */
  timesAboveMax: number;
}

/**
 * Snapshot of the leverage token state at a specific point in time
 *
 * @description
 * Used for tracking the evolution of the leverage token over time
 * during the simulation.
 */
export interface StateSnapshot {
  /** Timestamp of this snapshot (Unix seconds) */
  timestamp: number;

  /** Leverage token state at this time */
  state: LeverageTokenState;

  /** Market prices at this time */
  prices: MarketPrices;

  /** Borrow APY at this time */
  borrowAPY: number;

  /** Current collateral ratio */
  collateralRatio: number;

  /** Share price in collateral token units */
  sharePrice: number;

  /** Total equity in USD */
  equityUSD: number;
}
