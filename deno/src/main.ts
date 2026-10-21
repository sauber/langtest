#!/usr/bin/env -S deno run --allow-read
// Entry point of the Deno baseline: loads the market, runs the simulation and prints the report.
import { isAbsolute, resolve } from "node:path";
import { loadMarket } from "./data/loader.ts";
import { buildMarketIndex } from "./metrics/index.ts";
import { renderReport } from "./report/report.ts";
import { Simulator } from "./sim/simulator.ts";
import { RsiStrategy } from "./strategy/strategy.ts";

// Resolves the market data directory from the command line, falling back to the default location.
function resolveDataDir(args: readonly string[]): string | URL {
  const flag = args.find((arg) => arg.startsWith("--data="));
  if (flag === undefined) return new URL("../../data/", import.meta.url);
  const value = flag.slice("--data=".length);
  return isAbsolute(value) ? value : resolve(Deno.cwd(), value);
}

// Runs the evaluation end to end and prints the report to the terminal.
async function main(): Promise<void> {
  const market = await loadMarket(resolveDataDir(Deno.args));
  const strategy = new RsiStrategy();
  const result = new Simulator(market, strategy).run();
  const index = buildMarketIndex(market);
  const report = renderReport({
    market,
    strategyName: strategy.name,
    equity: result.equity,
    index,
    trades: result.trades,
    simSeconds: result.simSeconds,
  });
  console.log(report.join("\n"));
}

if (import.meta.main) {
  await main();
}
