import { DataAdapter, IDataAdapter } from './base';
import { BinanceAdapter } from './binance';
import { DeFiLlamaAdapter } from './defillama';
import { MorphoAdapter } from './morpho';

export function getAdapter(adapterName: DataAdapter): IDataAdapter {
  switch (adapterName) {
    case DataAdapter.BINANCE:
      return new BinanceAdapter();
    case DataAdapter.DEFILLAMA:
      return new DeFiLlamaAdapter();
    case DataAdapter.MORPHO:
      return new MorphoAdapter();
  }
}