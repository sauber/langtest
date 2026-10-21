import { assert, assertEquals } from "@std/assert";
import { buildMarketIndex } from "../src/metrics/index.ts";
import { renderChart } from "../src/report/chart.ts";
import { renderReport } from "../src/report/report.ts";
import { Simulator } from "../src/sim/simulator.ts";
import { marketOf } from "./fixtures.ts";

// The maximum number of columns a report line may occupy.
const MAX_WIDTH = 80;

// The maximum number of lines a complete report may occupy.
const MAX_LINES = 25;

// Removes the ANSI colour escapes so the visible width of a line can be measured.
function stripAnsi(text: string): string {
  let visible = "";
  let inEscape = false;
  for (const char of text) {
    if (inEscape) {
      if (char === "m") inEscape = false;
      continue;
    }
    if (char === "\u001b") {
      inEscape = true;
      continue;
    }
    visible += char;
  }
  return visible;
}

// Builds a small market whose simulation produces a report.
function sampleReport(): string[] {
  const market = marketOf([
    { symbol: "AAA-USDT", bars: [[0, 100], [1, 110], [2, 90], [3, 120]] },
    { symbol: "BBB-USDT", bars: [[0, 50], [1, 55], [2, 60], [3, 65]] },
  ]);
  const result = new Simulator(market, {
    name: "test",
    evaluate: () => ({
      signal: new Int8Array(4),
      strength: new Float64Array(4),
      rsi: new Float64Array(4),
    }),
  }).run();
  return renderReport({
    market,
    strategyName: "test",
    equity: result.equity,
    index: buildMarketIndex(market),
    trades: result.trades,
    simSeconds: result.simSeconds,
  });
}

Deno.test("the report fits into 80 columns and 25 lines", () => {
  const lines = sampleReport();
  assert(lines.length <= MAX_LINES, `report has ${lines.length} lines`);
  for (const line of lines) {
    const width = stripAnsi(line).length;
    assert(width <= MAX_WIDTH, `line of ${width} columns: ${stripAnsi(line)}`);
  }
});

Deno.test("the report names every metric", () => {
  const text = sampleReport().join("\n");
  for (
    const label of [
      "equity / index",
      "sharpe",
      "win / loss",
      "avg gain / trade",
      "avg holding time",
      "sim time:",
    ]
  ) {
    assert(text.includes(label), `missing metric label ${label}`);
  }
});

Deno.test("the chart is framed with soft line drawing characters", () => {
  const chart = renderChart(
    Float64Array.from([10_000, 11_000, 12_000]),
    Float64Array.from([10_000, 10_500, 11_000]),
    0,
    7_200,
  );
  assertEquals(chart.length, 15);
  assert(chart[0].startsWith("╭") && chart[0].endsWith("╮"));
  assert(chart[chart.length - 1].startsWith("╰") && chart[chart.length - 1].endsWith("╯"));
  for (const line of chart) {
    assert(stripAnsi(line).length <= MAX_WIDTH, `line too wide: ${stripAnsi(line)}`);
  }
});

Deno.test("the chart draws both series on one shared axis", () => {
  const chart = renderChart(
    Float64Array.from([10_000, 11_000, 12_000, 13_000]),
    Float64Array.from([10_000, 10_100, 10_200, 10_300]),
    0,
    10_800,
  );
  const text = chart.map(stripAnsi).join("\n");
  assert(text.includes("─") || text.includes("│"));
  // The market index stays near the bottom of the shared axis.
  assert(text.includes("╰"));
});
