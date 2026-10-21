import type { Market } from "../domain/types.ts";

// Builds the equal-weight buy-and-hold index of all coins over the simulation window.
export function buildMarketIndex(market: Market, initialCapital = 10_000): Float64Array {
  const { timeline, coins } = market;
  const steps = timeline.length;
  const index = new Float64Array(steps);
  const allocation = initialCapital / coins.length;
  for (const coin of coins) {
    if (coin.grid.barStep.length === 0) continue;
    const units = allocation / coin.closes[0];
    for (let step = coin.grid.barStep[0]; step < steps; step++) {
      index[step] += units * coin.grid.lastClose[step];
    }
  }
  return index;
}
