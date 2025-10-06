/**
 * DeFiLlama adapter for fetching on-chain asset prices
 */

import { PriceDataAdapter } from './base';
import { AssetConfig, PricePoint, TimeRange } from '../../types/data-sources';
import { AdapterName } from '.';

interface DeFiLlamaHistoricalResponse {
  coins: {
    [key: string]: {
      decimals: number;
      symbol: string;
      price: number;
      timestamp: number;
      confidence: number;
    };
  };
}

export class DeFiLlamaAdapter implements PriceDataAdapter {
  readonly name = AdapterName.DEFILLAMA;
  private readonly baseUrl = 'https://coins.llama.fi';

  canHandle(asset: AssetConfig): boolean {
    return !!asset.chain && !!asset.address;
  }

  async fetchPriceData(asset: AssetConfig, timeRange: TimeRange): Promise<PricePoint[]> {
    if (!asset.chain || !asset.address) {
      throw new Error(`DeFiLlama requires chain and address for ${asset.symbol}`);
    }

    const coinId = `${asset.chain}:${asset.address}`;

    console.log(`📥 [DeFiLlama] Fetching ${asset.symbol} (${coinId})`);

    // Fetch daily data points and interpolate to hourly
    // This reduces API calls from ~6500 to ~270
    const dayInSeconds = 86400;
    const hourInSeconds = 3600;

    const dailyTimestamps: number[] = [];
    for (let ts = timeRange.from; ts <= timeRange.to; ts += dayInSeconds) {
      dailyTimestamps.push(ts);
    }

    console.log(`  ↳ Fetching ${dailyTimestamps.length} daily points`);

    const allPrices: PricePoint[] = [];

    // Fetch in batches to avoid overwhelming the API
    const batchSize = 10;
    for (let i = 0; i < dailyTimestamps.length; i += batchSize) {
      const batch = dailyTimestamps.slice(i, i + batchSize);

      console.log(`  ↳ Batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(dailyTimestamps.length / batchSize)}`);

      for (const ts of batch) {
        const url = `${this.baseUrl}/prices/historical/${ts}/${coinId}`;

        try {
          const response = await fetch(url);

          if (!response.ok) {
            console.warn(`  ⚠️  Failed at ${ts}: ${response.status}`);
            continue;
          }

          const data = await response.json() as DeFiLlamaHistoricalResponse;
          const coinData = data.coins[coinId];

          if (coinData && coinData.price !== undefined) {
            allPrices.push({
              timestamp: ts,
              price: coinData.price,
            });
          }

          await new Promise(resolve => setTimeout(resolve, 200));
        } catch (error) {
          console.warn(`  ⚠️  Error at ${ts}:`, error);
        }
      }
    }

    // Sort by timestamp
    allPrices.sort((a, b) => a.timestamp - b.timestamp);

    // Interpolate to hourly
    const hourlyPrices: PricePoint[] = [];
    for (let i = 0; i < allPrices.length - 1; i++) {
      const current = allPrices[i]!;
      const next = allPrices[i + 1]!;

      // Add the current daily price
      hourlyPrices.push(current);

      // Interpolate hourly prices between this day and the next
      const priceStep = (next.price - current.price) / 24;
      for (let h = 1; h < 24; h++) {
        hourlyPrices.push({
          timestamp: current.timestamp + (h * hourInSeconds),
          price: current.price + (priceStep * h),
        });
      }
    }

    // Add the last day
    if (allPrices.length > 0) {
      hourlyPrices.push(allPrices[allPrices.length - 1]!);
    }

    console.log(`✅ [DeFiLlama] Fetched ${allPrices.length} daily points, interpolated to ${hourlyPrices.length} hourly points`);

    return hourlyPrices;
  }
}
