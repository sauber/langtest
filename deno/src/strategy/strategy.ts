import type { CoinSeries, SignalSeries } from "../domain/types.ts";
import { Signal } from "../domain/types.ts";
import { wilderRsi } from "./rsi.ts";

// The contract every trading strategy implements for the simulator.
export interface Strategy {
  readonly name: string;
  evaluate(coin: CoinSeries): SignalSeries;
}

// The RSI mean-reversion strategy: buy oversold, sell overbought.
export class RsiStrategy implements Strategy {
  readonly name = "RSI(14)";

  constructor(
    private readonly period = 14,
    private readonly oversold = 30,
    private readonly overbought = 70,
  ) {}

  // Turns the RSI of one coin into buy, sell and pass signals with their buy strength.
  evaluate(coin: CoinSeries): SignalSeries {
    const rsi = wilderRsi(coin.closes, this.period);
    const bars = coin.closes.length;
    const signal = new Int8Array(bars);
    const strength = new Float64Array(bars);
    for (let bar = 0; bar < bars; bar++) {
      const value = rsi[bar];
      if (Number.isNaN(value)) continue;
      if (value <= this.oversold) {
        signal[bar] = Signal.Buy;
        strength[bar] = this.oversold - value;
      } else if (value >= this.overbought) {
        signal[bar] = Signal.Sell;
      }
    }
    return { signal, strength, rsi };
  }
}
