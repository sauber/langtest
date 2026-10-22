// Download 1H klines for the top-20 USDT pairs by liquidity from KuCoin's public API.
//
// Every coin's bars are kept in memory while it downloads, before its CSV is written. When the
// last coin is on disk, the shared timeline and the equal-weight, step-rebalanced market index
// are built from the same in-memory data and written to data/meta.json.

const BASE_URL = "https://api.kucoin.com/api/v1";
const TARGET_COUNT = 20;
const MIN_PRICE = 1.0;
const INTERVAL = "1hour"; // KuCoin kline type for 1H candles
const CANDLES_PER_REQUEST = 1500; // API hard cap per request
const OUT_DIR = "data";
const REQUEST_DELAY_MS = 150; // Throttle between kline requests
const MAX_RETRIES = 5;
const MAX_PAGES = 1000; // Safety cap per coin
const BAR_SECONDS = 3600; // Length of one candle in seconds
const INITIAL_CAPITAL = 10_000; // Notional of the equal-weight market index
const INDEX_DECIMALS = 2; // Decimals the published index values carry
const META_FILE = "meta.json";
const CSV_HEADER = "timestamp,datetime,open,high,low,close,volume,turnover";
const PROGRESS_WIDTH = 24; // Width of the progress bar in characters

// Stablecoin bases to exclude, e.g. USDC-USDT and BUSD-USDT
const STABLE_BASES = new Set([
  "USDC",
  "BUSD",
  "DAI",
  "FDUSD",
  "TUSD",
  "USDP",
  "USDD",
  "PYUSD",
  "USD1",
  "USDE",
  "USDTB",
  "EURS",
  "AEUR",
  "XUSD",
  "SUSD",
  "USDBC",
  "DOLA",
  "MIM",
  "LUSD",
  "FRAX",
  "USDX",
  "USDT2",
  "AEUR",
  "EURT",
  "USDS",
  "USDY",
  "USD0",
]);

// One raw kline row of the KuCoin API: time, open, close, high, low, volume and turnover.
type Kline = readonly [string, string, string, string, string, string, string];

// One ticker of the KuCoin allTickers endpoint.
interface Ticker {
  readonly symbol: string;
  readonly last: string;
  readonly volValue: string;
}

// The payload of the KuCoin allTickers endpoint.
interface TickerPayload {
  readonly ticker: readonly Ticker[];
}

// The description of one coin's CSV file.
interface CoinMeta {
  readonly symbol: string;
  readonly file: string;
  readonly rows: number;
  readonly firstTimestamp: number;
  readonly lastTimestamp: number;
}

// The bars of one coin: what the meta file describes and the index is built from.
interface CoinAnalysis {
  readonly meta: CoinMeta;
  readonly timestamps: readonly number[];
  readonly closes: readonly number[];
}

// The shared simulation timeline: the sorted union of every coin's bar timestamps.
interface Timeline {
  readonly timestamps: readonly number[];
  readonly holeCount: number;
  readonly holeHours: number;
  readonly stepOf: ReadonlyMap<number, number>;
}

// The origin of the downloaded data.
interface SourceInfo {
  readonly exchange: string;
  readonly api: string;
  readonly interval: string;
  readonly intervalSeconds: number;
  readonly quoteCurrency: string;
  readonly selection: string;
}

// The facts about the downloaded files as a whole.
interface DatasetMeta {
  readonly fileCount: number;
  readonly filePattern: string;
  readonly header: string;
  readonly totalRows: number;
  readonly totalBytes: number;
}

// The facts about the shared simulation timeline.
interface TimelineMeta {
  readonly steps: number;
  readonly firstTimestamp: number;
  readonly lastTimestamp: number;
  readonly holeCount: number;
  readonly holeHours: number;
}

// The equal-weight market index, rebalanced at every step.
interface MarketIndexMeta {
  readonly definition: string;
  readonly initialCapital: number;
  readonly finalValue: number;
  readonly values: readonly number[];
}

// The machine-readable description of the downloaded market data.
interface MarketMeta {
  readonly schemaVersion: number;
  readonly generatedAt: string;
  readonly source: SourceInfo;
  readonly dataset: DatasetMeta;
  readonly timeline: TimelineMeta;
  readonly coins: readonly CoinMeta[];
  readonly marketIndex: MarketIndexMeta;
}

// The state of the download progress bar.
interface ProgressState {
  readonly startedAt: number;
  readonly totalCoins: number;
  coinsDone: number;
  completedCandles: number;
  currentCandles: number;
  symbol: string;
}

// The encoder the progress bar and the byte counts use.
const encoder = new TextEncoder();

// Formats a timestamp as the ISO-8601 UTC string the CSV files use.
function isoOf(timestamp: number): string {
  return new Date(timestamp * 1000).toISOString();
}

// Waits for the given number of milliseconds.
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// GET a KuCoin endpoint, retrying with backoff on rate limits and transient errors
async function fetchJson(path: string): Promise<unknown> {
  for (let attempt = 0;; attempt++) {
    try {
      const res = await fetch(`${BASE_URL}${path}`);
      if (res.status === 429 || res.status >= 500) {
        throw new Error(`HTTP ${res.status}`);
      }
      const body = await res.json();
      if (body.code !== "200000") {
        throw new Error(`API code ${body.code}: ${body.msg}`);
      }
      return body.data;
    } catch (err) {
      if (attempt >= MAX_RETRIES) throw err;
      const backoff = 500 * 2 ** attempt + Math.random() * 250;
      console.error(
        `  retry ${attempt + 1}/${MAX_RETRIES} in ${
          Math.round(backoff)
        }ms: ${err}`,
      );
      await sleep(backoff);
    }
  }
}

// Fetch all tickers, then pick top-20 USDT pairs with price > $1, excluding stablecoins
async function selectTopCoins(): Promise<
  { symbol: string; last: number; volValue: number }[]
> {
  const data = await fetchJson("/market/allTickers") as TickerPayload;
  const candidates = data.ticker
    .map((t) => ({
      symbol: t.symbol,
      last: parseFloat(t.last),
      volValue: parseFloat(t.volValue), // liquidity = 24h volume in USDT
    }))
    .filter((t) => t.symbol.endsWith("-USDT"))
    .filter((t) => t.last > MIN_PRICE)
    .filter((t) => !STABLE_BASES.has(t.symbol.slice(0, -5)))
    .sort((a, b) => b.volValue - a.volValue)
    .slice(0, TARGET_COUNT);
  return candidates;
}

// Pages backward through 1H candles until an empty page, then return them sorted oldest-first
async function downloadCandles(
  symbol: string,
  progress: ProgressState,
): Promise<Kline[]> {
  const rows: Kline[] = [];
  const hour = 3600;
  let endAt = Math.floor(Date.now() / 1000 / hour) * hour; // align to candle boundary
  let pages = 0;

  while (pages < MAX_PAGES) {
    const startAt = endAt - CANDLES_PER_REQUEST * hour;
    const batch = await fetchJson(
      `/market/candles?symbol=${symbol}&type=${INTERVAL}&startAt=${startAt}&endAt=${endAt}`,
    ) as readonly Kline[];
    pages++;
    if (batch.length === 0) break; // reached the earliest available candle
    for (const row of batch) rows.push(row);
    const oldest = Math.min(...batch.map((r) => +r[0]));
    endAt = oldest; // endAt is exclusive on KuCoin, so this resumes exactly at the oldest candle
    progress.currentCandles = rows.length;
    renderProgress(progress);
    await sleep(REQUEST_DELAY_MS);
  }

  // Rows are newest-first with duplicates across page boundaries; sort ascending and dedupe
  const deduped = new Map<string, Kline>();
  for (const r of rows) deduped.set(r[0], r);
  return [...deduped.values()].sort((a, b) => +a[0] - +b[0]);
}

// Extracts the timestamps and closes of one coin while its rows are still in memory
function extractBars(symbol: string, rows: readonly Kline[]): CoinAnalysis {
  const timestamps = new Array<number>(rows.length);
  const closes = new Array<number>(rows.length);
  for (let bar = 0; bar < rows.length; bar++) {
    timestamps[bar] = Number(rows[bar][0]);
    closes[bar] = Number(rows[bar][2]);
  }
  return {
    meta: {
      symbol,
      file: `${symbol}.csv`,
      rows: rows.length,
      firstTimestamp: timestamps[0] ?? 0,
      lastTimestamp: timestamps[timestamps.length - 1] ?? 0,
    },
    timestamps,
    closes,
  };
}

// Renders the bars of one coin as the CSV text the file holds.
function buildCsv(rows: readonly Kline[]): string {
  const lines = new Array<string>(rows.length + 1);
  lines[0] = CSV_HEADER;
  for (let i = 0; i < rows.length; i++) {
    const [time, open, close, high, low, volume, turnover] = rows[i];
    lines[i + 1] = [
      time,
      isoOf(Number(time)),
      open,
      high,
      low,
      close,
      volume,
      turnover,
    ].join(",");
  }
  return lines.join("\n") + "\n";
}

// Writes the CSV text of one coin to the data directory.
async function writeCsv(symbol: string, text: string): Promise<void> {
  await Deno.writeTextFile(`${OUT_DIR}/${symbol}.csv`, text);
}

// Builds the shared timeline: the sorted union of every coin's bar timestamps
function buildTimeline(analyses: readonly CoinAnalysis[]): Timeline {
  const all: number[] = [];
  for (const analysis of analyses) {
    for (const timestamp of analysis.timestamps) all.push(timestamp);
  }
  all.sort((a, b) => a - b);

  const timestamps: number[] = [];
  const stepOf = new Map<number, number>();
  let holeCount = 0;
  let holeHours = 0;
  let index = 0;
  while (index < all.length) {
    const timestamp = all[index];
    while (index < all.length && all[index] === timestamp) index++;
    if (timestamps.length > 0) {
      const missing =
        (timestamp - timestamps[timestamps.length - 1]) / BAR_SECONDS - 1;
      if (missing > 0) {
        holeCount++;
        holeHours += missing;
      }
    }
    stepOf.set(timestamp, timestamps.length);
    timestamps.push(timestamp);
  }
  return { timestamps, holeCount, holeHours, stepOf };
}

// Builds the equal-weight market index: at every step the whole portfolio is pretend-sold for
// zero fees and split equally across the coins that report here and at the next step
function buildMarketIndex(
  analyses: readonly CoinAnalysis[],
  timeline: Timeline,
): Float64Array {
  const steps = timeline.timestamps.length;
  const coins = analyses.length;
  const index = new Float64Array(steps);

  // The step of every bar of every coin, and whether that bar is followed by the next step
  const barSteps: Int32Array[] = [];
  const followed: Uint8Array[] = [];
  for (const analysis of analyses) {
    const barStep = new Int32Array(analysis.timestamps.length);
    for (let bar = 0; bar < barStep.length; bar++) {
      barStep[bar] = timeline.stepOf.get(analysis.timestamps[bar]) ?? -1;
    }
    const isFollowed = new Uint8Array(barStep.length);
    for (let bar = 0; bar + 1 < barStep.length; bar++) {
      isFollowed[bar] = barStep[bar + 1] === barStep[bar] + 1 ? 1 : 0;
    }
    barSteps.push(barStep);
    followed.push(isFollowed);
  }

  const lastClose = new Float64Array(coins).fill(Number.NaN);
  const units = new Float64Array(coins);
  const nextBar = new Int32Array(coins);
  const available: number[] = [];
  let cash = INITIAL_CAPITAL;

  for (let step = 0; step < steps; step++) {
    // Mark every coin that reports at this step to its close and collect the available ones
    available.length = 0;
    for (let coin = 0; coin < coins; coin++) {
      const bar = nextBar[coin];
      if (bar < barSteps[coin].length && barSteps[coin][bar] === step) {
        lastClose[coin] = analyses[coin].closes[bar];
        if (followed[coin][bar]) available.push(coin);
        nextBar[coin] = bar + 1;
      }
    }
    // Value the portfolio in cash plus the holdings at their last known close
    let value = cash;
    for (let coin = 0; coin < coins; coin++) {
      if (!Number.isNaN(lastClose[coin])) {
        value += units[coin] * lastClose[coin];
      }
    }
    // Pretend everything is sold and split the total equally across the available coins
    if (available.length > 0) {
      const share = value / available.length;
      units.fill(0);
      for (const coin of available) units[coin] = share / lastClose[coin];
      cash = 0;
    }
    index[step] = value;
  }
  return index;
}

// Rounds a value to the decimals the published index values carry.
function roundIndexValue(value: number): number {
  const factor = 10 ** INDEX_DECIMALS;
  return Math.round(value * factor) / factor;
}

// Builds the facts about the downloaded files as a whole.
function buildDatasetMeta(
  analyses: readonly CoinAnalysis[],
  totalBytes: number,
): DatasetMeta {
  return {
    fileCount: analyses.length,
    filePattern: "<SYMBOL>-USDT.csv",
    header: CSV_HEADER,
    totalRows: analyses.reduce((sum, analysis) => sum + analysis.meta.rows, 0),
    totalBytes,
  };
}

// Builds the facts about the shared timeline for the meta file.
function buildTimelineMeta(timeline: Timeline): TimelineMeta {
  const steps = timeline.timestamps.length;
  return {
    steps,
    firstTimestamp: steps > 0 ? timeline.timestamps[0] : 0,
    lastTimestamp: steps > 0 ? timeline.timestamps[steps - 1] : 0,
    holeCount: timeline.holeCount,
    holeHours: timeline.holeHours,
  };
}

// Assembles the machine-readable description of the downloaded market data.
function buildMeta(
  analyses: readonly CoinAnalysis[],
  timeline: Timeline,
  index: Float64Array,
  totalBytes: number,
): MarketMeta {
  const values = Array.from(index, roundIndexValue);
  return {
    schemaVersion: 2,
    generatedAt: new Date().toISOString(),
    source: {
      exchange: "KuCoin",
      api: BASE_URL,
      interval: INTERVAL,
      intervalSeconds: BAR_SECONDS,
      quoteCurrency: "USDT",
      selection:
        `top ${TARGET_COUNT} USDT pairs by 24h quote volume, price above ${MIN_PRICE} USDT, stablecoins excluded`,
    },
    dataset: buildDatasetMeta(analyses, totalBytes),
    timeline: buildTimelineMeta(timeline),
    coins: analyses.map((analysis) => analysis.meta),
    marketIndex: {
      definition:
        "equal-weight portfolio: at every step the whole value is split, with zero fees, across the coins that report at the current and at the next step",
      initialCapital: INITIAL_CAPITAL,
      finalValue: values.length > 0 ? values[values.length - 1] : 0,
      values,
    },
  };
}

// Removes the CSV files of the coins that are no longer part of the selection.
async function pruneStaleCoins(symbols: readonly string[]): Promise<string[]> {
  const removed: string[] = [];
  for await (const entry of Deno.readDir(OUT_DIR)) {
    if (!entry.isFile || !entry.name.endsWith(".csv")) continue;
    if (symbols.includes(entry.name.slice(0, -".csv".length))) continue;
    await Deno.remove(`${OUT_DIR}/${entry.name}`);
    removed.push(entry.name);
  }
  return removed;
}

// The placeholder the compact index series is spliced in at.
const VALUES_PLACEHOLDER = "__INDEX_VALUES__";

// Writes the description of the downloaded data to the meta file; the index series stays on
// one line so the file does not grow by one indented line per value
async function writeMeta(meta: MarketMeta): Promise<void> {
  const shell = {
    ...meta,
    marketIndex: { ...meta.marketIndex, values: VALUES_PLACEHOLDER },
  };
  const text = JSON.stringify(shell, null, 2).replace(
    `"${VALUES_PLACEHOLDER}"`,
    `[${meta.marketIndex.values.join(",")}]`,
  );
  await Deno.writeTextFile(`${OUT_DIR}/${META_FILE}`, `${text}\n`);
}

// Estimates the seconds left until every coin is downloaded.
function estimateRemainingSeconds(progress: ProgressState): number {
  const elapsed = (Date.now() - progress.startedAt) / 1000;
  const candles = progress.completedCandles + progress.currentCandles;
  if (elapsed <= 0 || candles <= 0) return 0;
  const rate = candles / elapsed;
  const coins = Math.max(
    progress.coinsDone + (progress.currentCandles > 0 ? 1 : 0),
    1,
  );
  const averageCoin = candles / coins;
  const remaining = Math.max(
    averageCoin * (progress.totalCoins - progress.coinsDone) -
      progress.currentCandles,
    0,
  );
  return Math.round(remaining / rate);
}

// Renders the progress bar with the estimated seconds left.
function renderProgress(progress: ProgressState): void {
  if (!Deno.stdout.isTerminal()) return;
  const ratio = progress.totalCoins > 0
    ? progress.coinsDone / progress.totalCoins
    : 0;
  const filled = Math.round(ratio * PROGRESS_WIDTH);
  const bar = "█".repeat(filled) + "░".repeat(PROGRESS_WIDTH - filled);
  const percent = String(Math.round(ratio * 100)).padStart(3);
  const candles = (progress.completedCandles + progress.currentCandles)
    .toLocaleString("en-US");
  const eta = estimateRemainingSeconds(progress);
  const line =
    `[${bar}] ${percent}%  ${progress.coinsDone}/${progress.totalCoins} · ${progress.symbol} · ${candles} candles · ETA ${eta}s`;
  Deno.stdout.writeSync(encoder.encode(`\r${line.padEnd(78)}`));
}

// Clears the progress bar from the terminal.
function clearProgress(): void {
  if (!Deno.stdout.isTerminal()) return;
  Deno.stdout.writeSync(encoder.encode(`\r${" ".repeat(78)}\r`));
}

// Prints the summary of one downloaded coin.
function reportCoin(symbol: string, rows: number, bytes: number): void {
  console.log(
    `  ${symbol.padEnd(14)} ${String(rows).padStart(7)} candles  ${
      (bytes / 1024 / 1024).toFixed(1)
    } MB`,
  );
}

// Orchestrate: select coins, download + extract + save each, print a summary
async function main(): Promise<void> {
  const coins = await selectTopCoins();
  console.log(
    `Selected ${coins.length} coins (price > $1, top ${TARGET_COUNT} by volValue):\n`,
  );
  coins.forEach((c, i) =>
    console.log(
      `  ${String(i + 1).padStart(2)}. ${
        c.symbol.padEnd(14)
      } last=$${c.last} volValue=$${c.volValue.toLocaleString("en-US")}`,
    )
  );

  await Deno.mkdir(OUT_DIR, { recursive: true });
  console.log("");

  const progress: ProgressState = {
    startedAt: Date.now(),
    totalCoins: coins.length,
    coinsDone: 0,
    completedCandles: 0,
    currentCandles: 0,
    symbol: "connecting",
  };

  const analyses: CoinAnalysis[] = [];
  let totalBytes = 0;
  for (const coin of coins) {
    progress.symbol = coin.symbol;
    progress.currentCandles = 0;
    const rows = await downloadCandles(coin.symbol, progress);
    const text = buildCsv(rows);
    const bytes = encoder.encode(text).length;
    analyses.push(extractBars(coin.symbol, rows));
    await writeCsv(coin.symbol, text);
    totalBytes += bytes;
    progress.coinsDone++;
    progress.completedCandles += rows.length;
    progress.currentCandles = 0;
    clearProgress();
    reportCoin(coin.symbol, rows.length, bytes);
    if (coin !== coins[coins.length - 1]) await sleep(REQUEST_DELAY_MS);
  }

  const removed = await pruneStaleCoins(coins.map((coin) => coin.symbol));
  if (removed.length > 0) {
    console.log(
      `  removed ${removed.length} stale file(s): ${removed.join(", ")}`,
    );
  }

  // The implementations read the coins in alphabetical order (the loader sorts them). The
  // alphabetical tie-break of the buy rule depends on that order, so the meta must follow it.
  analyses.sort((a, b) => a.meta.symbol.localeCompare(b.meta.symbol));

  const timeline = buildTimeline(analyses);
  const index = buildMarketIndex(analyses, timeline);
  const meta = buildMeta(analyses, timeline, index, totalBytes);
  await writeMeta(meta);
  clearProgress();

  console.log(
    `\nDone: ${coins.length} coins, ${meta.dataset.totalRows} candles, ${
      (totalBytes / 1024 / 1024).toFixed(1)
    } MB, saved to ${OUT_DIR}/`,
  );
  console.log(
    `      ${meta.timeline.steps} timeline steps, ${meta.timeline.holeCount} holes, market index ${
      meta.marketIndex.finalValue.toFixed(2)
    }`,
  );
  console.log(`      wrote ${OUT_DIR}/${META_FILE}`);
}

await main();
