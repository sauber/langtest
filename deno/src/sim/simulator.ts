import type { CoinSeries, Market, SignalSeries, SimulationResult } from "../domain/types.ts";
import { Signal } from "../domain/types.ts";
import type { Strategy } from "../strategy/strategy.ts";
import { Portfolio } from "./portfolio.ts";

// Steps the market step by step, applying the strategy's signals to a single position.
export class Simulator {
  private readonly signals: Int8Array[];
  private readonly strengths: Float64Array[];

  constructor(
    private readonly market: Market,
    private readonly strategy: Strategy,
    private readonly initialCash = 10_000,
    private readonly feeRate = 0.001,
  ) {
    const steps = market.timeline.length;
    this.signals = market.coins.map(() => new Int8Array(steps));
    this.strengths = market.coins.map(() => new Float64Array(steps));
    market.coins.forEach((coin, index) => this.applySignals(coin, index));
  }

  // Runs the simulation loop and returns the equity curve together with the closed trades.
  run(): SimulationResult {
    const { timeline, coins } = this.market;
    const steps = timeline.length;
    const portfolio = new Portfolio(this.initialCash, this.feeRate);
    const equity = new Float64Array(steps);
    const started = performance.now();
    for (let step = 0; step < steps; step++) {
      const held = portfolio.openPosition;
      if (held !== null && this.signals[held.coinIndex][step] === Signal.Sell) {
        portfolio.sell(coins[held.coinIndex].grid.close[step], step);
      }
      if (portfolio.openPosition === null) {
        const choice = this.selectBuy(step);
        if (choice >= 0) {
          portfolio.buy(coins[choice].symbol, choice, coins[choice].grid.close[step], step);
        }
      }
      const position = portfolio.openPosition;
      equity[step] = portfolio.markValue(
        position === null ? 0 : coins[position.coinIndex].grid.lastClose[step],
      );
    }
    const simSeconds = (performance.now() - started) / 1000;
    const finalEquity = steps > 0 ? equity[steps - 1] : this.initialCash;
    return { equity, trades: portfolio.trades, finalEquity, simSeconds };
  }

  // Scatters the strategy's signals of one coin onto the shared simulation timeline.
  private applySignals(coin: CoinSeries, index: number): void {
    const series: SignalSeries = this.strategy.evaluate(coin);
    const { barStep } = coin.grid;
    for (let bar = 0; bar < barStep.length; bar++) {
      this.signals[index][barStep[bar]] = series.signal[bar];
      this.strengths[index][barStep[bar]] = series.strength[bar];
    }
  }

  // Picks the coin with the strongest buy signal, breaking ties alphabetically.
  private selectBuy(step: number): number {
    let best = -1;
    let bestStrength = -Infinity;
    let bestSymbol = "";
    for (let index = 0; index < this.signals.length; index++) {
      if (this.signals[index][step] !== Signal.Buy) continue;
      const strength = this.strengths[index][step];
      const symbol = this.market.coins[index].symbol;
      const better = best < 0 ||
        strength > bestStrength ||
        (strength === bestStrength && symbol < bestSymbol);
      if (better) {
        best = index;
        bestStrength = strength;
        bestSymbol = symbol;
      }
    }
    return best;
  }
}
