// Signal codes shared by every strategy implementation.
export type SignalCode = 0 | 1 | 2;

// The trading signals a strategy can emit for a single bar.
export const Signal = {
  Pass: 0,
  Buy: 1,
  Sell: 2,
} as const;

// The per-bar signal series a strategy derives from one coin's price history.
export interface SignalSeries {
  readonly signal: Int8Array;
  readonly strength: Float64Array;
  readonly rsi: Float64Array;
}

// One raw market bar reduced to the fields the strategy and simulator need.
export interface Bar {
  readonly timestamp: number;
  readonly close: number;
}

// The bar history of a single coin in chronological order.
export interface BarHistory {
  readonly symbol: string;
  readonly timestamps: number[];
  readonly closes: number[];
}

// The price grid of one coin aligned to the shared simulation timeline.
export interface CoinGrid {
  readonly close: Float64Array;
  readonly lastClose: Float64Array;
  readonly barStep: Int32Array;
}

// One coin's history together with its timeline-aligned price grid.
export interface CoinSeries {
  readonly symbol: string;
  readonly timestamps: Float64Array;
  readonly closes: Float64Array;
  readonly grid: CoinGrid;
}

// The simulation timeline together with every coin aligned to it.
export interface Market {
  readonly timeline: Float64Array;
  readonly coins: readonly CoinSeries[];
}

// The single open position the account may hold at any time.
export interface Position {
  readonly symbol: string;
  readonly coinIndex: number;
  readonly quantity: number;
  readonly costBasis: number;
  readonly entryStep: number;
}

// A closed round-trip trade with both legs net of the trading fee.
export interface Trade {
  readonly symbol: string;
  readonly entryStep: number;
  readonly exitStep: number;
  readonly quantity: number;
  readonly costBasis: number;
  readonly proceeds: number;
  readonly netReturn: number;
}

// The outcome of one simulation run.
export interface SimulationResult {
  readonly equity: Float64Array;
  readonly trades: readonly Trade[];
  readonly finalEquity: number;
  readonly simSeconds: number;
}
