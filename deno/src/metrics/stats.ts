import type { Trade } from "../domain/types.ts";

// The number of hours in a year, used to annualise the hourly Sharpe ratio.
const HOURS_PER_YEAR = 8760;

// The win and loss counts of a set of closed trades.
export interface WinLossSummary {
  readonly wins: number;
  readonly losses: number;
  readonly ratio: number;
}

// Computes the annualised Sharpe ratio of an account value curve.
export function sharpeRatio(equity: Float64Array): number | null {
  const count = equity.length - 1;
  if (count < 2) return null;
  const returns = new Float64Array(count);
  let sum = 0;
  for (let step = 1; step < equity.length; step++) {
    returns[step - 1] = equity[step] / equity[step - 1] - 1;
    sum += returns[step - 1];
  }
  const mean = sum / count;
  let squares = 0;
  for (let index = 0; index < count; index++) {
    squares += (returns[index] - mean) ** 2;
  }
  const deviation = Math.sqrt(squares / (count - 1));
  if (deviation === 0) return null;
  return (mean / deviation) * Math.sqrt(HOURS_PER_YEAR);
}

// Counts the winning and losing closed trades and derives their ratio.
export function winLossRatio(trades: readonly Trade[]): WinLossSummary {
  let wins = 0;
  let losses = 0;
  for (const trade of trades) {
    if (trade.netReturn > 0) wins++;
    else if (trade.netReturn < 0) losses++;
  }
  return { wins, losses, ratio: losses === 0 ? Infinity : wins / losses };
}

// Averages the net return over every closed trade.
export function averageGain(trades: readonly Trade[]): number {
  if (trades.length === 0) return 0;
  let sum = 0;
  for (const trade of trades) sum += trade.netReturn;
  return sum / trades.length;
}

// Averages the number of simulation steps a closed trade was held.
export function averageHoldingSteps(trades: readonly Trade[]): number {
  if (trades.length === 0) return 0;
  let sum = 0;
  for (const trade of trades) sum += trade.exitStep - trade.entryStep;
  return sum / trades.length;
}
