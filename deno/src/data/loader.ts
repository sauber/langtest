import type { BarHistory, CoinSeries, Market } from "../domain/types.ts";
import { CsvScanner } from "./scanner.ts";

// Drains every complete row the scanner can produce into the given arrays.
function drain(scanner: CsvScanner, timestamps: number[], closes: number[]): void {
  for (let bar = scanner.next(); bar !== null; bar = scanner.next()) {
    timestamps.push(bar.timestamp);
    closes.push(bar.close);
  }
}

// Streams one CSV file into the parallel timestamp and close arrays of one coin.
export async function readCoin(
  path: string | URL,
  symbol: string,
): Promise<BarHistory> {
  const file = await Deno.open(path, { read: true });
  const decoder = new TextDecoder();
  const scanner = new CsvScanner();
  const timestamps: number[] = [];
  const closes: number[] = [];
  for await (const chunk of file.readable) {
    scanner.push(decoder.decode(chunk, { stream: true }));
    drain(scanner, timestamps, closes);
  }
  scanner.push(decoder.decode());
  drain(scanner, timestamps, closes);
  return { symbol, timestamps, closes };
}

// Builds the shared simulation timeline as the sorted union of every coin's timestamps.
export function buildTimeline(histories: readonly BarHistory[]): Float64Array {
  const stamps = new Set<number>();
  for (const history of histories) {
    for (const timestamp of history.timestamps) stamps.add(timestamp);
  }
  return Float64Array.from([...stamps].sort((a, b) => a - b));
}

// Aligns every coin's bar history to the shared simulation timeline.
export function alignToTimeline(
  timeline: Float64Array,
  histories: readonly BarHistory[],
): CoinSeries[] {
  const steps = timeline.length;
  return histories.map((history) => {
    const close = new Float64Array(steps).fill(NaN);
    const barStep = new Int32Array(history.timestamps.length);
    let cursor = 0;
    for (let bar = 0; bar < history.timestamps.length; bar++) {
      const timestamp = history.timestamps[bar];
      while (cursor < steps && timeline[cursor] < timestamp) cursor++;
      barStep[bar] = cursor;
      close[cursor] = history.closes[bar];
    }
    const lastClose = new Float64Array(steps).fill(NaN);
    let previous = NaN;
    for (let step = 0; step < steps; step++) {
      if (!Number.isNaN(close[step])) previous = close[step];
      lastClose[step] = previous;
    }
    return {
      symbol: history.symbol,
      timestamps: Float64Array.from(history.timestamps),
      closes: Float64Array.from(history.closes),
      grid: { close, lastClose, barStep },
    };
  });
}

// Resolves the path of one coin file inside the data directory.
function coinPath(dataDir: string | URL, symbol: string): string | URL {
  if (dataDir instanceof URL) return new URL(`${symbol}.csv`, dataDir);
  return `${dataDir.replace(/\/+$/, "")}/${symbol}.csv`;
}

// Loads every coin CSV of a directory and aligns all coins to one simulation timeline.
export async function loadMarket(dataDir: string | URL): Promise<Market> {
  const symbols: string[] = [];
  for await (const entry of Deno.readDir(dataDir)) {
    if (entry.isFile && entry.name.endsWith(".csv")) {
      symbols.push(entry.name.slice(0, -".csv".length));
    }
  }
  symbols.sort();
  const histories: BarHistory[] = [];
  for (const symbol of symbols) {
    histories.push(await readCoin(coinPath(dataDir, symbol), symbol));
  }
  const timeline = buildTimeline(histories);
  return { timeline, coins: alignToTimeline(timeline, histories) };
}
