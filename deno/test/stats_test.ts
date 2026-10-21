import { assertAlmostEquals, assertEquals } from "@std/assert";
import type { Trade } from "../src/domain/types.ts";
import { buildMarketIndex } from "../src/metrics/index.ts";
import {
  averageGain,
  averageHoldingSteps,
  sharpeRatio,
  winLossRatio,
} from "../src/metrics/stats.ts";
import { marketOf } from "./fixtures.ts";

// Builds a synthetic closed trade for the metric tests.
function trade(netReturn: number, entryStep = 0, exitStep = 1): Trade {
  return {
    symbol: "AAA-USDT",
    entryStep,
    exitStep,
    quantity: 1,
    costBasis: 100,
    proceeds: 100 * (1 + netReturn),
    netReturn,
  };
}

Deno.test("sharpe ratio is zero for symmetric hourly returns", () => {
  const sharpe = sharpeRatio(Float64Array.from([100, 110, 99]));
  assertAlmostEquals(sharpe ?? 0, 0, 1e-12);
});

Deno.test("sharpe ratio is undefined when the returns do not vary", () => {
  assertEquals(sharpeRatio(Float64Array.from([100, 110, 121])), null);
});

Deno.test("sharpe ratio needs at least two returns", () => {
  assertEquals(sharpeRatio(Float64Array.from([100, 110])), null);
});

Deno.test("sharpe ratio annualises the sample deviation of the hourly returns", () => {
  const sharpe = sharpeRatio(Float64Array.from([100, 110, 121, 110]));
  // Returns 0.1, 0.1 and -11/121 give a mean of 0.03636363636363636 and a sample deviation of
  // 0.11022141502711037.
  const mean = 0.03636363636363636;
  const deviation = 0.11022141502711037;
  assertAlmostEquals(sharpe ?? 0, (mean / deviation) * Math.sqrt(8760), 1e-12);
  assertAlmostEquals(sharpe ?? 0, 30.87829962538582, 1e-12);
});

Deno.test("win and loss counts skip trades that break even", () => {
  const summary = winLossRatio([trade(0.1), trade(-0.05), trade(0), trade(0.02)]);
  assertEquals(summary.wins, 2);
  assertEquals(summary.losses, 1);
  assertAlmostEquals(summary.ratio, 2, 1e-12);
});

Deno.test("win and loss ratio is infinite without a loss", () => {
  const summary = winLossRatio([trade(0.1), trade(0.02)]);
  assertEquals(summary.losses, 0);
  assertEquals(summary.ratio, Infinity);
});

Deno.test("average gain covers winners and losers alike", () => {
  assertAlmostEquals(averageGain([trade(0.1), trade(-0.05), trade(0), trade(0.02)]), 0.0175, 1e-12);
});

Deno.test("average gain of an empty trade list is zero", () => {
  assertEquals(averageGain([]), 0);
});

Deno.test("average holding time counts the simulation steps between entry and exit", () => {
  assertAlmostEquals(averageHoldingSteps([trade(0.1, 0, 5), trade(-0.1, 2, 3)]), 3, 1e-12);
});

Deno.test("average holding time of an empty trade list is zero", () => {
  assertEquals(averageHoldingSteps([]), 0);
});

Deno.test("the market index invests the equal share at the first bar of every coin", () => {
  const market = marketOf([
    { symbol: "AAA-USDT", bars: [[0, 100]] },
    { symbol: "BBB-USDT", bars: [[1, 200]] },
  ]);
  const index = buildMarketIndex(market, 10_000);
  // Each coin receives 5,000 at its own first bar: 50 units of AAA and 25 units of BBB.
  assertAlmostEquals(index[0], 5_000, 1e-9);
  assertAlmostEquals(index[1], 10_000, 1e-9);
});

Deno.test("the market index tracks the last known close of every coin", () => {
  const market = marketOf([
    { symbol: "AAA-USDT", bars: [[0, 100], [2, 300]] },
    { symbol: "BBB-USDT", bars: [[0, 10], [1, 10], [2, 10]] },
  ]);
  const index = buildMarketIndex(market, 10_000);
  // AAA is worth 50 units, BBB is worth 500 units of its own first close.
  assertAlmostEquals(index[1], 50 * 100 + 500 * 10, 1e-9);
  assertAlmostEquals(index[2], 50 * 300 + 500 * 10, 1e-9);
});
