/**
 * CLI script to run backtests on Leverage Token strategies
 *
 * Usage: pnpm backtest
 */

import { promises as fs } from 'fs';
import path from 'path';
import { Backtester, HistoricalData, BacktestConfig } from './Backtester';
import { STRATEGIES } from '../types/strategy';
import { AssetData } from '../types/data-sources';

async function loadData(dataDir: string, symbol: string): Promise<AssetData> {
  const filePath = path.join(dataDir, `${symbol}.json`);
  const content = await fs.readFile(filePath, 'utf-8');
  return JSON.parse(content) as AssetData;
}

async function main() {
  console.log('🎯 Leverage Token Backtester\n');

  // Configuration
  const strategyName = 'WEETH-WETH-17x';
  const strategy = STRATEGIES[strategyName];

  if (!strategy) {
    console.error(`❌ Strategy "${strategyName}" not found`);
    process.exit(1);
  }

  const dataDir = './data';
  const resultsDir = './results';
  const initialDepositCollateral = 1.0; // 1 weETH
  const estimatedRebalanceGasCost = 5; // $5 USD per rebalance
  const managementFeePercentage = 0.02; // 2% annual management fee

  console.log(`📋 Configuration:`);
  console.log(`   Strategy: ${strategy.name}`);
  console.log(`   Initial deposit: ${initialDepositCollateral} ${strategy.collateral.symbol}`);
  console.log(`   Collateral ratios: min=${strategy.collateralRatios.min}, target=${strategy.collateralRatios.target}, max=${strategy.collateralRatios.max}`);
  console.log(`   Backtest period: ${new Date(strategy.timeRangeBacktest.from * 1000).toISOString().split('T')[0]} → ${new Date(strategy.timeRangeBacktest.to * 1000).toISOString().split('T')[0]}`);
  console.log(`   Estimated rebalance cost: $${estimatedRebalanceGasCost}`);
  console.log(`   Management fee: ${(managementFeePercentage * 100).toFixed(2)}% per year\n`);

  // Load historical data
  console.log(`📂 Loading historical data...`);

  try {
    const debtPrices = await loadData(dataDir, strategy.debt.symbol);
    const collateralPrices = await loadData(dataDir, strategy.collateral.symbol);
    const morphoMarketFile = `MORPHO-${strategy.lendingMarket.marketId.substring(0, 10)}`;
    const borrowAPY = await loadData(dataDir, morphoMarketFile);

    console.log(`   ✓ ${strategy.debt.symbol}: ${debtPrices.data.length} price points`);
    console.log(`   ✓ ${strategy.collateral.symbol}: ${collateralPrices.data.length} price points`);
    console.log(`   ✓ ${morphoMarketFile}: ${borrowAPY.data.length} APY points\n`);

    const historicalData: HistoricalData = {
      debtPrices,
      collateralPrices,
      borrowAPY,
    };

    // Initialize backtester
    const backtester = new Backtester();
    backtester.loadData(historicalData);

    const config: BacktestConfig = {
      strategy,
      initialDepositCollateral,
      estimatedRebalanceGasCost,
      managementFeePercentage,
    };

    backtester.initialize(config);

    // Run simulation
    const result = await backtester.run();

    // Display results
    console.log(`\n${'='.repeat(60)}`);
    console.log(`📊 BACKTEST RESULTS - ${result.strategyName}`);
    console.log(`${'='.repeat(60)}\n`);

    console.log(`📅 Period:`);
    console.log(`   Start: ${new Date(result.period.start * 1000).toISOString().split('T')[0]}`);
    console.log(`   End:   ${new Date(result.period.end * 1000).toISOString().split('T')[0]}`);
    console.log(`   Duration: ${result.period.durationDays.toFixed(1)} days\n`);

    console.log(`💰 Performance:`);
    console.log(`   Initial Share Price: ${result.metrics.initialSharePrice.toFixed(6)} ${strategy.collateral.symbol}`);
    console.log(`   Final Share Price:   ${result.metrics.finalSharePrice.toFixed(6)} ${strategy.collateral.symbol}`);
    console.log(`   Total Return:        ${result.metrics.totalReturn.toFixed(2)}%`);
    console.log(`   Annualized Return:   ${result.metrics.annualizedReturn.toFixed(2)}%`);
    console.log(`   Max Drawdown:        ${result.metrics.maxDrawdown.toFixed(2)}%\n`);

    console.log(`🔄 Rebalancing:`);
    console.log(`   Total Rebalances:    ${result.metrics.rebalanceCount}`);
    console.log(`   Gas Costs (est):     $${result.metrics.totalGasCostsUSD.toFixed(2)}`);
    console.log(`   Avg Collateral Ratio: ${result.metrics.avgCollateralRatio.toFixed(6)}`);
    console.log(`   Times Below Min:     ${result.metrics.timesBelowMin}`);
    console.log(`   Times Above Max:     ${result.metrics.timesAboveMax}\n`);

    // Show rebalance history
    if (result.rebalances.length > 0) {
      console.log(`📜 Rebalance History (first 10):`);
      result.rebalances.slice(0, 10).forEach((rebalance, idx) => {
        const date = new Date(rebalance.stateBefore.timestamp * 1000).toISOString().split('T')[0];
        console.log(`   ${idx + 1}. ${date} - ${rebalance.direction} (${rebalance.ratioBefore.toFixed(4)} → ${rebalance.ratioAfter.toFixed(4)})`);
      });
      if (result.rebalances.length > 10) {
        console.log(`   ... and ${result.rebalances.length - 10} more\n`);
      } else {
        console.log('');
      }
    }

    // Save results to file (convert BigInt to string for JSON)
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const resultsPath = path.join(resultsDir, `${strategyName}-${timestamp}.json`);
    await fs.writeFile(resultsPath, JSON.stringify(result, (key, value) =>
      typeof value === 'bigint' ? value.toString() : value
    , 2));
    console.log(`💾 Results saved to: ${resultsPath}\n`);

    console.log(`${'='.repeat(60)}\n`);

  } catch (error) {
    console.error('❌ Error during backtest:', error);
    process.exit(1);
  }
}

main();
