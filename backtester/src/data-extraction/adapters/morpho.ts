/**
 * Morpho adapter for fetching borrow APY data from Morpho Blue markets
 */

import { DataAdapter, IDataAdapter } from './base';
import { AssetConfig, PricePoint, TimeRange } from '../../types/data-sources';

interface MorphoGraphQLResponse {
  data: {
    marketByUniqueKey: {
      id: string;
      uniqueKey: string;
      historicalState: {
        dailyNetBorrowApy: Array<{
          x: number;
          y: number;
          __typename: string;
        }>;
        __typename: string;
      };
      __typename: string;
    };
  };
}

export class MorphoAdapter implements IDataAdapter {
  readonly name = DataAdapter.MORPHO;
  private readonly baseUrl = 'https://app.morpho.org/api/graphql';

  canHandle(asset: AssetConfig): boolean {
    return !!asset.lendingMarketId && !!asset.chainId && asset.lendingAdapter === DataAdapter.MORPHO;
  }

  async fetchPriceData(asset: AssetConfig, timeRange: TimeRange): Promise<PricePoint[]> {
    if (!asset.lendingMarketId || !asset.chainId) {
      throw new Error(`Morpho adapter requires lendingMarketId and chainId for ${asset.symbol}`);
    }

    console.log(`📥 [Morpho] Fetching borrow APY for market ${asset.lendingMarketId.substring(0, 10)}...`);

    const query = {
      operationName: 'GetMarketBorrowApyTimeseries',
      variables: {
        uniqueKey: asset.lendingMarketId,
        chainId: asset.chainId,
        options: {
          startTimestamp: timeRange.from,
          endTimestamp: timeRange.to,
          interval: 'DAY',
        },
      },
      query: `query GetMarketBorrowApyTimeseries($uniqueKey: String!, $chainId: Int!, $options: TimeseriesOptions) {
  marketByUniqueKey(uniqueKey: $uniqueKey, chainId: $chainId) {
    id
    uniqueKey
    historicalState {
      dailyNetBorrowApy(options: $options) {
        x
        y
        __typename
      }
      __typename
    }
    __typename
  }
}`,
    };

    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(query),
    });

    if (!response.ok) {
      throw new Error(`Morpho GraphQL API error: ${response.status}`);
    }

    const data = await response.json() as MorphoGraphQLResponse;

    if (!data.data?.marketByUniqueKey) {
      throw new Error(`Market not found: ${asset.lendingMarketId}`);
    }

    const apyData = data.data.marketByUniqueKey.historicalState.dailyNetBorrowApy;

    const prices: PricePoint[] = apyData.map((point) => ({
      timestamp: point.x,
      price: point.y,
    }));

    console.log(`✅ [Morpho] Fetched ${prices.length} daily APY points`);

    return prices;
  }
}
