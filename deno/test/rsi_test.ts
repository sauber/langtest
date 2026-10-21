import { assertAlmostEquals, assertEquals } from "@std/assert";
import { wilderRsi } from "../src/strategy/rsi.ts";

// The classic Wilder example: 33 closing prices of a single security.
const WILDER_CLOSES = [
  44.34,
  44.09,
  44.15,
  43.61,
  44.33,
  44.83,
  45.1,
  45.42,
  45.84,
  46.08,
  45.89,
  46.03,
  45.61,
  46.28,
  46.28,
  46.0,
  46.03,
  46.41,
  46.22,
  45.64,
  46.21,
  46.25,
  45.71,
  46.45,
  45.78,
  45.35,
  44.03,
  44.18,
  44.22,
  44.57,
  43.42,
  42.66,
  43.13,
];

// The RSI values the canonical Wilder algorithm produces for that series.
const WILDER_RSI = [
  70.46,
  66.25,
  66.48,
  69.35,
  66.29,
  57.92,
  62.88,
  63.21,
  56.01,
  62.34,
  54.67,
  50.39,
  40.02,
  41.49,
  41.9,
  45.5,
  37.32,
  33.09,
  37.79,
];

// The RSI of a three period oscillator over five closes, derived by hand.
const SHORT_CLOSES = [10, 11, 13, 12, 14];

// The hand computed RSI values of that short series: 1 + 2 = 3 gain and 1 loss over 3 periods.
const SHORT_RSI = [75, 85.71428571428571];

Deno.test("rsi is undefined until the first period of changes is complete", () => {
  const rsi = wilderRsi(WILDER_CLOSES);
  for (let bar = 0; bar < 14; bar++) {
    assertEquals(Number.isNaN(rsi[bar]), true, `bar ${bar} should have no rsi`);
  }
  assertEquals(Number.isNaN(rsi[14]), false);
});

Deno.test("rsi matches the published Wilder values", () => {
  const rsi = wilderRsi(WILDER_CLOSES);
  for (let index = 0; index < WILDER_RSI.length; index++) {
    assertAlmostEquals(rsi[14 + index], WILDER_RSI[index], 0.005, `rsi bar ${14 + index}`);
  }
});

Deno.test("rsi seeds the average gain and loss over the first period", () => {
  const rsi = wilderRsi(WILDER_CLOSES);
  // Gains 0.06 + 0.72 + 0.5 + 0.27 + 0.32 + 0.42 + 0.24 + 0.14 + 0.67 = 3.34 over 14 periods.
  // Losses 0.25 + 0.54 + 0.19 + 0.42 = 1.4 over 14 periods.
  assertAlmostEquals(rsi[14], 100 - 100 / (1 + (3.34 / 14) / (1.4 / 14)), 1e-12);
});

Deno.test("rsi follows the smoothing recurrence", () => {
  const rsi = wilderRsi(SHORT_CLOSES, 3);
  assertAlmostEquals(rsi[3], SHORT_RSI[0], 1e-12);
  assertAlmostEquals(rsi[4], SHORT_RSI[1], 1e-12);
});

Deno.test("rsi is 100 for a series that only rises", () => {
  const rsi = wilderRsi([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  assertEquals(rsi[14], 100);
});

Deno.test("rsi is 0 for a series that only falls", () => {
  const rsi = wilderRsi([16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
  assertEquals(rsi[14], 0);
});

Deno.test("rsi is empty for a series that is too short", () => {
  const rsi = wilderRsi([1, 2, 3]);
  assertEquals(rsi.length, 3);
  assertEquals(rsi.every((value) => Number.isNaN(value)), true);
});
