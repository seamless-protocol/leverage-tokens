/**
 * Main entry point for data extraction
 * Run with: pnpm extract
 */

import { StrategyExtractor } from './strategy-extractor';
import { STRATEGIES } from '../types/strategy';

async function main() {
  console.log('🚀 Data Extraction\n');

  // Configuration
  const strategyName = 'WEETH-WETH-17x';
  const strategy = STRATEGIES[strategyName];

  if (!strategy) {
    console.error(`❌ Strategy "${strategyName}" not found`);
    process.exit(1);
  }

  console.log(`📅 Time Range:`);
  console.log(`   From: ${new Date(strategy.timeRangeData.from * 1000).toISOString()}`);
  console.log(`   To:   ${new Date(strategy.timeRangeData.to * 1000).toISOString()}`);

  // Create extractor
  const extractor = new StrategyExtractor('./data');

  try {
    // Extract data
    await extractor.extract(strategy, strategy.timeRangeData);

    console.log('✅ All data extracted successfully!\n');
    console.log('📁 Data saved to: ./data/');
    console.log('   - ETH.json (base asset)');
    console.log('   - weETH.json (collateral asset)');
  } catch (error) {
    console.error('❌ Error during extraction:', error);
    process.exit(1);
  }
}

main();
