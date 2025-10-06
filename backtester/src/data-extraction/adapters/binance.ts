/**
 * Binance adapter for fetching price data
 * Returns only close prices in unified PricePoint format
 */

import Binance, { CandleChartInterval } from 'binance-api-node';
import { PriceDataAdapter } from './base';
import { AssetConfig, PricePoint, TimeRange, Timeframe } from '../../types/data-sources';
import { AdapterName } from '.';

export class BinanceAdapter implements PriceDataAdapter {
  readonly name = AdapterName.BINANCE;
  private client: ReturnType<typeof Binance>;

  constructor() {
    this.client = Binance();
  }

  canHandle(asset: AssetConfig): boolean {
    return !asset.chain && !asset.address;
  }

  async fetchPriceData(asset: AssetConfig, timeRange: TimeRange): Promise<PricePoint[]> {
    const symbol = this.getSymbolForBinance(asset.symbol);
    const interval = this.mapTimeframeToBinanceInterval(asset.timeframe);

    console.log(`📥 [Binance] Fetching ${symbol} (${interval})`);

    const prices = await this.fetchPricesInBatches(
      symbol,
      interval,
      timeRange.from * 1000,
      timeRange.to * 1000
    );

    console.log(`✅ [Binance] Fetched ${prices.length} price points`);

    return prices;
  }

  private async fetchPricesInBatches(
    symbol: string,
    interval: CandleChartInterval,
    startTime: number,
    endTime: number
  ): Promise<PricePoint[]> {
    const allPrices: PricePoint[] = [];
    const intervalMs = this.getIntervalMs(interval);
    const lastCandleEndTime = endTime - (endTime % intervalMs);

    let lastEndTime = startTime;

    while (lastEndTime < lastCandleEndTime) {
      const candles = await this.client.candles({
        symbol,
        interval,
        startTime: lastEndTime,
        endTime: lastCandleEndTime - 1,
        limit: 1000,
      });

      if (candles.length === 0) break;

      const prices: PricePoint[] = candles.map((candle) => ({
        timestamp: Math.floor(candle.openTime / 1000),
        price: parseFloat(candle.close),
      }));

      allPrices.push(...prices);
      lastEndTime = candles[candles.length - 1]!.closeTime;
    }

    return allPrices;
  }

  private mapTimeframeToBinanceInterval(timeframe: Timeframe): CandleChartInterval {
    const mapping: Record<Timeframe, string> = {
      '1m': CandleChartInterval.ONE_MINUTE,
      '3m': CandleChartInterval.THREE_MINUTES,
      '5m': CandleChartInterval.FIVE_MINUTES,
      '15m': CandleChartInterval.FIFTEEN_MINUTES,
      '30m': CandleChartInterval.THIRTY_MINUTES,
      '1h': CandleChartInterval.ONE_HOUR,
      '4h': CandleChartInterval.FOUR_HOURS,
      '1d': CandleChartInterval.ONE_DAY,
      '1w': CandleChartInterval.ONE_WEEK,
    };
    return mapping[timeframe] as CandleChartInterval;
  }

  private getIntervalMs(interval: CandleChartInterval): number {
    if (interval === CandleChartInterval.ONE_MINUTE) return 60 * 1000;
    if (interval === CandleChartInterval.THREE_MINUTES) return 3 * 60 * 1000;
    if (interval === CandleChartInterval.FIVE_MINUTES) return 5 * 60 * 1000;
    if (interval === CandleChartInterval.FIFTEEN_MINUTES) return 15 * 60 * 1000;
    if (interval === CandleChartInterval.THIRTY_MINUTES) return 30 * 60 * 1000;
    if (interval === CandleChartInterval.ONE_HOUR) return 60 * 60 * 1000;
    if (interval === CandleChartInterval.FOUR_HOURS) return 4 * 60 * 60 * 1000;
    if (interval === CandleChartInterval.ONE_DAY) return 24 * 60 * 60 * 1000;
    if (interval === CandleChartInterval.ONE_WEEK) return 7 * 24 * 60 * 60 * 1000;
    return 60 * 1000;
  }

  private getSymbolForBinance(symbol: string): string {
    if (symbol === 'USDT' || symbol === 'USDC') {
      return 'BTCUSDT';
    }
    return `${symbol}USDT`;
  }
}
