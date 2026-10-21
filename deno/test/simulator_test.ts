import { assertAlmostEquals, assertEquals } from "@std/assert";
import { Signal } from "../src/domain/types.ts";
import { Simulator } from "../src/sim/simulator.ts";
import type { Script } from "./fixtures.ts";
import { marketOf, ScriptedStrategy } from "./fixtures.ts";

// Runs a scripted simulation and returns its result.
function run(
  specs: readonly { symbol: string; bars: readonly (readonly [number, number])[] }[],
  script: Record<string, Script>,
) {
  const market = marketOf(specs);
  return new Simulator(market, new ScriptedStrategy(script)).run();
}

Deno.test("a buy spends all cash and pays the entry fee", () => {
  const result = run(
    [{ symbol: "AAA-USDT", bars: [[0, 100], [1, 110]] }],
    { "AAA-USDT": { signal: [Signal.Buy, Signal.Pass] } },
  );
  // 10,000 cash buys 10,000 / (100 * 1.001) units, worth 10,000 / 1.001 at the close.
  assertAlmostEquals(result.equity[0], 10_000 / 1.001, 1e-9);
  assertEquals(result.trades.length, 0);
});

Deno.test("a sell closes the position and pays the exit fee", () => {
  const result = run(
    [{ symbol: "AAA-USDT", bars: [[0, 100], [1, 110]] }],
    { "AAA-USDT": { signal: [Signal.Buy, Signal.Sell] } },
  );
  const quantity = 10_000 / (100 * 1.001);
  const proceeds = quantity * 110 * 0.999;
  assertEquals(result.trades.length, 1);
  assertAlmostEquals(result.trades[0].costBasis, 10_000, 1e-9);
  assertAlmostEquals(result.trades[0].proceeds, proceeds, 1e-9);
  assertAlmostEquals(result.trades[0].netReturn, proceeds / 10_000 - 1, 1e-12);
  assertAlmostEquals(result.equity[1], proceeds, 1e-9);
  assertEquals(result.trades[0].entryStep, 0);
  assertEquals(result.trades[0].exitStep, 1);
});

Deno.test("only one position is held at a time", () => {
  const result = run(
    [
      { symbol: "AAA-USDT", bars: [[0, 100], [1, 100], [2, 500]] },
      { symbol: "BBB-USDT", bars: [[0, 200], [1, 200], [2, 210]] },
    ],
    {
      "AAA-USDT": { signal: [Signal.Buy, Signal.Pass, Signal.Pass], strength: [5] },
      "BBB-USDT": { signal: [Signal.Buy, Signal.Buy, Signal.Pass], strength: [10, 10] },
    },
  );
  // The stronger buy signal wins, and the weaker coin never gets bought.
  assertAlmostEquals(result.equity[2], (10_000 / (200 * 1.001)) * 210, 1e-9);
  assertEquals(result.trades.length, 0);
});

Deno.test("the strongest buy signal wins", () => {
  const result = run(
    [
      { symbol: "AAA-USDT", bars: [[0, 100], [1, 100], [2, 500]] },
      { symbol: "BBB-USDT", bars: [[0, 200], [1, 200], [2, 210]] },
    ],
    {
      "AAA-USDT": { signal: [Signal.Buy, Signal.Pass, Signal.Pass], strength: [5] },
      "BBB-USDT": { signal: [Signal.Buy, Signal.Pass, Signal.Pass], strength: [10] },
    },
  );
  assertAlmostEquals(result.equity[2], (10_000 / (200 * 1.001)) * 210, 1e-9);
});

Deno.test("equal buy strengths are broken alphabetically", () => {
  const result = run(
    [
      { symbol: "AAA-USDT", bars: [[0, 100], [1, 300]] },
      { symbol: "BBB-USDT", bars: [[0, 200], [1, 200]] },
    ],
    {
      "AAA-USDT": { signal: [Signal.Buy, Signal.Pass], strength: [10] },
      "BBB-USDT": { signal: [Signal.Buy, Signal.Pass], strength: [10] },
    },
  );
  assertAlmostEquals(result.equity[1], (10_000 / (100 * 1.001)) * 300, 1e-9);
});

Deno.test("a position is carried forward across a data gap", () => {
  const result = run(
    [
      { symbol: "AAA-USDT", bars: [[0, 100], [3, 120]] },
      { symbol: "BBB-USDT", bars: [[0, 50], [1, 50], [2, 50], [3, 50]] },
    ],
    {
      "AAA-USDT": { signal: [Signal.Buy, Signal.Sell] },
      "BBB-USDT": { signal: [Signal.Pass, Signal.Pass, Signal.Pass, Signal.Pass] },
    },
  );
  const quantity = 10_000 / (100 * 1.001);
  // Without a bar of its own the coin cannot be sold and keeps its last known close.
  assertAlmostEquals(result.equity[1], quantity * 100, 1e-9);
  assertAlmostEquals(result.equity[2], quantity * 100, 1e-9);
  assertEquals(result.trades.length, 1);
  assertEquals(result.trades[0].exitStep, 3);
  assertAlmostEquals(result.equity[3], quantity * 120 * 0.999, 1e-9);
});

Deno.test("a sell may be followed by a new buy in the same step", () => {
  const result = run(
    [
      { symbol: "AAA-USDT", bars: [[0, 100], [1, 110]] },
      { symbol: "BBB-USDT", bars: [[0, 50], [1, 50]] },
    ],
    {
      "AAA-USDT": { signal: [Signal.Buy, Signal.Sell] },
      "BBB-USDT": { signal: [Signal.Pass, Signal.Buy] },
    },
  );
  const proceeds = (10_000 / (100 * 1.001)) * 110 * 0.999;
  assertEquals(result.trades.length, 1);
  assertEquals(result.trades[0].symbol, "AAA-USDT");
  // The freed cash is immediately used to buy the other coin, so only the entry fee is lost.
  assertAlmostEquals(result.equity[1], proceeds / 1.001, 1e-9);
});

Deno.test("the equity curve records the account value of every step", () => {
  const result = run(
    [{ symbol: "AAA-USDT", bars: [[0, 100], [1, 100], [2, 100]] }],
    { "AAA-USDT": { signal: [Signal.Pass, Signal.Pass, Signal.Pass] } },
  );
  assertEquals(result.equity.length, 3);
  assertAlmostEquals(result.equity[0], 10_000, 1e-9);
  assertAlmostEquals(result.equity[2], 10_000, 1e-9);
  assertAlmostEquals(result.finalEquity, 10_000, 1e-9);
});
