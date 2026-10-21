// Download 1H klines for the top-20 USDT pairs by liquidity from KuCoin's public API.

const BASE_URL = "https://api.kucoin.com/api/v1";
const TARGET_COUNT = 20;
const MIN_PRICE = 1.0;
const INTERVAL = "1hour"; // KuCoin kline type for 1H candles
const CANDLES_PER_REQUEST = 1500; // API hard cap per request
const OUT_DIR = "data";
const REQUEST_DELAY_MS = 150; // Throttle between kline requests
const MAX_RETRIES = 5;
const MAX_PAGES = 1000; // Safety cap per coin

// Stablecoin bases to exclude, e.g. USDC-USDT and BUSD-USDT
const STABLE_BASES = new Set([
  "USDC", "BUSD", "DAI", "FDUSD", "TUSD", "USDP", "USDD", "PYUSD", "USD1",
  "USDE", "USDTB", "EURS", "AEUR", "XUSD", "SUSD", "USDBC", "DOLA", "MIM",
  "LUSD", "FRAX", "USDX", "USDT2", "AEUR", "EURT", "USDS", "USDY", "USD0",
]);

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// GET a KuCoin endpoint, retrying with backoff on rate limits and transient errors
async function fetchJson(path: string): Promise<any> {
  for (let attempt = 0; ; attempt++) {
    try {
      const res = await fetch(`${BASE_URL}${path}`);
      if (res.status === 429 || res.status >= 500) throw new Error(`HTTP ${res.status}`);
      const body = await res.json();
      if (body.code !== "200000") throw new Error(`API code ${body.code}: ${body.msg}`);
      return body.data;
    } catch (err) {
      if (attempt >= MAX_RETRIES) throw err;
      const backoff = 500 * 2 ** attempt + Math.random() * 250;
      console.error(`  retry ${attempt + 1}/${MAX_RETRIES} in ${Math.round(backoff)}ms: ${err}`);
      await sleep(backoff);
    }
  }
}

// Fetch all tickers, then pick top-20 USDT pairs with price > $1, excluding stablecoins
async function selectTopCoins(): Promise<{ symbol: string; last: number; volValue: number }[]> {
  const data = await fetchJson("/market/allTickers");
  const candidates = (data.ticker as any[])
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

// Page backward through 1H candles until an empty page, then return them sorted oldest-first
async function downloadCandles(symbol: string): Promise<string[][]> {
  const rows: string[][] = [];
  const hour = 3600;
  let endAt = Math.floor(Date.now() / 1000 / hour) * hour; // align to candle boundary
  let pages = 0;

  while (pages < MAX_PAGES) {
    const startAt = endAt - CANDLES_PER_REQUEST * hour;
    const batch: string[][] = await fetchJson(
      `/market/candles?symbol=${symbol}&type=${INTERVAL}&startAt=${startAt}&endAt=${endAt}`,
    );
    pages++;
    if (batch.length === 0) break; // reached the earliest available candle
    rows.push(...batch);
    const oldest = Math.min(...batch.map((r) => +r[0]));
    endAt = oldest; // endAt is exclusive on KuCoin, so this resumes exactly at the oldest candle
    process.stdout.write(`\r  ${symbol}: ${rows.length} candles (${pages} requests)`);
    await sleep(REQUEST_DELAY_MS);
  }
  process.stdout.write("\n");

  // Rows are newest-first with duplicates across page boundaries; sort ascending and dedupe
  const deduped = new Map<string, string[]>();
  for (const r of rows) deduped.set(r[0], r);
  return [...deduped.values()].sort((a, b) => +a[0] - +b[0]);
}

// Write candles to data/<SYMBOL>.csv with an ISO datetime column added
async function writeCsv(symbol: string, candles: string[][]): Promise<void> {
  const lines = ["timestamp,datetime,open,high,low,close,volume,turnover"];
  for (const [time, open, close, high, low, volume, turnover] of candles) {
    lines.push(
      [time, new Date(+time * 1000).toISOString(), open, high, low, close, volume, turnover].join(","),
    );
  }
  await Deno.writeTextFile(`${OUT_DIR}/${symbol}.csv`, lines.join("\n") + "\n");
}

// Orchestrate: select coins, download + save each, print a summary
async function main(): Promise<void> {
  const coins = await selectTopCoins();
  console.log(`Selected ${coins.length} coins (price > $1, top ${TARGET_COUNT} by volValue):\n`);
  coins.forEach((c, i) =>
    console.log(
      `  ${String(i + 1).padStart(2)}. ${c.symbol.padEnd(14)} last=$${c.last} volValue=$${c.volValue.toLocaleString("en-US")}`,
    )
  );

  await Deno.mkdir(OUT_DIR, { recursive: true });
  console.log("");
  let totalCandles = 0;
  for (const coin of coins) {
    const candles = await downloadCandles(coin.symbol);
    await writeCsv(coin.symbol, candles);
    totalCandles += candles.length;
    if (coin !== coins[coins.length - 1]) await sleep(REQUEST_DELAY_MS);
  }
  console.log(`\nDone: ${coins.length} coins, ${totalCandles} candles total, saved to ${OUT_DIR}/`);
}

await main();
