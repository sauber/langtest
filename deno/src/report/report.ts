import type { Market, Trade } from "../domain/types.ts";
import { averageGain, averageHoldingSteps, sharpeRatio, winLossRatio } from "../metrics/stats.ts";
import { renderChart } from "./chart.ts";

// The width of the label column of the metrics block.
const LABEL_WIDTH = 18;

// The width of the value column of the metrics block.
const VALUE_WIDTH = 10;

// The ANSI colour of the strategy equity legend marker.
const EQUITY_COLOR = "96";

// The ANSI colour of the market index legend marker.
const INDEX_COLOR = "95";

// Everything the report needs to describe one simulation run.
export interface ReportInput {
  readonly market: Market;
  readonly strategyName: string;
  readonly equity: Float64Array;
  readonly index: Float64Array;
  readonly trades: readonly Trade[];
  readonly simSeconds: number;
}

// Formats a number with thousands separators and no decimals.
export function formatInt(value: number): string {
  const rounded = Math.round(value).toString();
  return rounded.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Formats a ratio as a fixed-precision multiple.
function formatRatio(value: number): string {
  return `${value.toFixed(4)}x`;
}

// Formats a fraction as a signed percentage.
function formatPercent(value: number): string {
  return `${value >= 0 ? "+" : ""}${(value * 100).toFixed(4)}%`;
}

// Builds one aligned row of the metrics block.
function metric(label: string, value: string, detail = ""): string {
  return `${label.padEnd(LABEL_WIDTH)}${value.padStart(VALUE_WIDTH)}${detail}`;
}

// Builds the report as an array of terminal lines.
export function renderReport(input: ReportInput): string[] {
  const { market, equity, index, trades, simSeconds } = input;
  const steps = market.timeline.length;
  const first = market.timeline[0];
  const last = market.timeline[steps - 1];
  const ratio = equity[steps - 1] / index[steps - 1];
  const sharpe = sharpeRatio(equity);
  const { wins, losses, ratio: winLoss } = winLossRatio(trades);
  const lines: string[] = [];
  lines.push(
    `${input.strategyName} · ${market.coins.length} coins · ${formatInt(steps)} hourly steps · ` +
      `${new Date(first * 1000).toISOString().slice(0, 10)} → ` +
      `${new Date(last * 1000).toISOString().slice(0, 10)}`,
  );
  lines.push(
    metric(
      "equity / index",
      formatRatio(ratio),
      `  (equity ${formatInt(equity[steps - 1])} · index ${formatInt(index[steps - 1])})`,
    ),
  );
  lines.push(metric("sharpe (hourly)", sharpe === null ? "N/A" : sharpe.toFixed(4)));
  lines.push(
    metric(
      "win / loss",
      trades.length === 0 ? "N/A" : winLoss === Infinity ? "inf" : winLoss.toFixed(4),
      `  (${wins} W / ${losses} L / ${trades.length} trades)`,
    ),
  );
  lines.push(
    metric("avg gain / trade", trades.length === 0 ? "N/A" : formatPercent(averageGain(trades))),
  );
  lines.push(
    metric(
      "avg holding time",
      trades.length === 0 ? "N/A" : `${averageHoldingSteps(trades).toFixed(2)} h`,
    ),
  );
  lines.push(`sim time: ${simSeconds.toFixed(3)} s`);
  lines.push(...renderChart(equity, index, first, last));
  lines.push(
    `\x1b[${EQUITY_COLOR}m●\x1b[0m strategy equity (cyan)   ` +
      `\x1b[${INDEX_COLOR}m●\x1b[0m market index (magenta, shared axis)`,
  );
  return lines;
}
