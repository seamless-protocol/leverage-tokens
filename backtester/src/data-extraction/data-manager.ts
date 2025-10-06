/**
 * DataManager handles storage and gap detection for price data
 * Ensures we never re-fetch data we already have
 */

import { promises as fs } from 'fs';
import path from 'path';
import { AssetData, PricePoint, TimeRange, Timeframe } from '../types/data-sources';
import { DataAdapter } from './adapters/base';

export class DataManager {
  private dataDir: string;

  constructor(dataDir: string = './data') {
    this.dataDir = dataDir;
  }

  /**
   * Ensure we have data for an asset in the given time range
   * Fetches only missing gaps
   */
  async ensureData(
    symbol: string,
    source: DataAdapter,
    timeframe: Timeframe,
    timeRange: TimeRange,
    fetcher: (gap: TimeRange) => Promise<PricePoint[]>
  ): Promise<AssetData> {
    // Load existing data
    const existing = await this.load(symbol);

    // Detect gaps
    const gaps = this.detectGaps(existing.data, timeRange);

    if (gaps.length === 0) {
      console.log(`💾 [Cache] ${symbol} already has complete data for range`);
      return existing;
    }

    // Fetch gaps
    console.log(`🔍 [Gap] ${symbol} has ${gaps.length} gap(s) to fetch`);

    for (const gap of gaps) {
      console.log(`  ↳ Fetching gap: ${new Date(gap.from * 1000).toISOString()} → ${new Date(gap.to * 1000).toISOString()}`);
      const newData = await fetcher(gap);
      existing.data.push(...newData);
    }

    // Sort, dedupe, and save
    existing.data.sort((a, b) => a.timestamp - b.timestamp);
    existing.data = this.dedupe(existing.data);
    existing.source = source;
    existing.timeframe = timeframe;

    await this.save(symbol, existing);

    return existing;
  }

  /**
   * Detect gaps in existing data compared to needed range
   */
  private detectGaps(data: PricePoint[], needed: TimeRange): TimeRange[] {
    if (data.length === 0) {
      // No data at all, need entire range
      return [needed];
    }

    const min = data[0]!.timestamp;
    const max = data[data.length - 1]!.timestamp;

    const gaps: TimeRange[] = [];

    // Gap before existing data
    if (needed.from < min) {
      gaps.push({ from: needed.from, to: min - 1 });
    }

    // Gap after existing data
    if (needed.to > max) {
      gaps.push({ from: max + 1, to: needed.to });
    }

    return gaps;
  }

  /**
   * Remove duplicate timestamps (keep first occurrence)
   */
  private dedupe(data: PricePoint[]): PricePoint[] {
    const seen = new Set<number>();
    return data.filter((point) => {
      if (seen.has(point.timestamp)) {
        return false;
      }
      seen.add(point.timestamp);
      return true;
    });
  }

  /**
   * Load asset data from file
   */
  private async load(symbol: string): Promise<AssetData> {
    const filepath = path.join(this.dataDir, `${symbol}.json`);

    try {
      const content = await fs.readFile(filepath, 'utf-8');
      return JSON.parse(content) as AssetData;
    } catch {
      // File doesn't exist, return empty
      // TODO: should we throw an error here?
      return {
        symbol,
        source: DataAdapter.BINANCE,
        timeframe: '5m',
        data: [],
      };
    }
  }

  /**
   * Save asset data to file
   */
  private async save(symbol: string, data: AssetData): Promise<void> {
    // Ensure directory exists
    await fs.mkdir(this.dataDir, { recursive: true });

    const filepath = path.join(this.dataDir, `${symbol}.json`);
    await fs.writeFile(filepath, JSON.stringify(data, null, 2), 'utf-8');

    console.log(`💾 [Save] ${symbol}.json (${data.data.length} price points)`);
  }
}
