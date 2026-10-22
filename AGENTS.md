# Programming Language Evaluation

This project implements the same trading-strategy evaluator in each
candidate language to showcase idiomatic style and unique language features.
Each implementation should follow the specification's functional requirements
but use best practices and idiomatic architecture, data structures, and
patterns for its language. Architecture is open for each implementation.
Results need not match exactly across implementations; variation is
acceptable and expected. The Deno implementation is just another
implementation among others, not a canonical reference to copy.

## Repository layout

- `data/` — shared market data, generated and git-ignored: one CSV per coin
  (20 files, e.g. `data/BTC-USDT.csv`) plus `data/meta.json`.
- `download_kucoin.ts` — existing Deno script that populates `data/`. It
  analyses every coin while it is still in memory and writes the analysis to
  `data/meta.json` when the download finishes. Do not modify or re-run it
  unless data must be refreshed.
- One folder per language at the repository root: `deno/`, `rust/`, `go/`,
  `elixir/`, `elm/`, `scala/`, `raku/`. Each folder contains that language's
  full implementation:
  source code, unit tests, and a README. The README must begin with a header
  giving instructions for how to run the test suite and how to run the
  evaluation, followed by any build commands.
- Each implementation reads `data/*.csv`, runs the simulation and metrics
  defined below, and prints results to the terminal. No GUI frameworks.

## Test data

Market data is already present in `data/`, one CSV per coin (20 files, e.g.
`data/BTC-USDT.csv`). Schema, in order:

- `timestamp` — Unix seconds of the candle open time
- `datetime` — ISO-8601 UTC of the candle open time
- `open,high,low,close` — prices in USDT
- `volume` — base-coin volume
- `turnover` — quote volume in USDT

Rows are sorted ascending by `timestamp`, 1-hour candles. Coins have different
first and last timestamps, and rows may be missing for hours inside a coin's
range (gaps). Never assume a continuous hourly series.

### The meta file

`data/meta.json` is the machine-readable description of the downloaded market
data, written by `download_kucoin.ts` as part of the download. It holds the
bare minimum needed to plan an implementation and run the evaluation: the
source and file conventions, the coin list with coverage, the shared
simulation timeline, and the equal-weight, step-rebalanced market index
series (`marketIndex.values`, one value per simulation step).

**Read the meta file to understand the data source — in particular while
planning an implementation — instead of opening or scanning the CSV files.**
The CSVs are ~91 MB; read the meta file first, and the CSVs only for
per-bar detail the meta file does not carry.

## Strategy

For each coin and each bar, the strategy produces one signal:

- **buy** — RSI ≤ 30
- **sell** — RSI ≥ 70
- **pass** — otherwise (or RSI not yet computable)

RSI is the 14-period Relative Strength Index using Wilder's smoothing, computed
on closing prices. The first RSI value needs 14 closes; bars before that have no
signal. The numeric **buy strength** of a coin is `30 - RSI` (larger = more
oversold). The strategy is a separate, swappable component: the simulator takes
the strategy as input.

## Simulator

Fixed parameters:

- Initial capital: 10,000 USDT
- Fee: 0.1% on every buy and every sell
- Single position maximum: the account holds zero or one coin at a time. While
  holding a coin, no purchase may occur, even of a different coin.

Execution rules, applied in order at each step:

1. Build the simulation timeline as the sorted union of all bar timestamps
   across all 20 coins, from the earliest to the latest bar. Step through it
   once, hourly.
2. At each timestamp, if a coin is held and that coin has a bar at this
   timestamp with a **sell** signal: sell the entire position at this bar's
   close price. Proceeds = quantity × close × 0.999.
3. Then, if no coin is held and at least one coin has a bar at this timestamp
   with a **buy** signal: buy the coin with the highest buy strength using all
   available cash. Coins are allowed to be fractional. Quantity = cash / (close
   × 1.001). On equal strengths, pick the alphabetically first symbol.
4. If a coin is held but has no bar at the current timestamp (data gap), no
   trade is possible for it; the position carries forward.
5. After the trade rules, record account value: cash + quantity × last known
   close of the held coin (last known = most recent close at or before this
   timestamp; if the coin has no bars yet, it cannot be held).

Only the original position's coin is checked for a sell signal — re-entry in the
same step after a sell is allowed (rules 2 then 3).

### Performance of the step loop

The hourly stepping loop is the hot path of every implementation and must be
optimized for execution speed — the reported `sim time` is the headline
benchmark when the languages are compared. Keep it allocation-free, avoid
repeated scans over all coins, and index bars by timestamp for constant-time
access. Signals may be computed ahead of the loop: precomputing RSI and buy
strengths is allowed and encouraged, since only the loop itself is timed.

Optimizations may change how state is represented, never what the simulation
does.

## Performance metrics

After the simulation completes, compute:

1. **End result vs. market index.** Build an equal-weighted, rebalanced index
   starting at 10,000 USDT: at every simulation step, first value the portfolio
   (cash plus holdings at their last known closes), then — with zero fees —
   pretend everything is sold and split the total equally across the coins
   *available* at that step, each bought at that step's close. A coin is
   available at a step only when it has a bar at that step and also a bar at
   the next step, so the index never holds a coin across a data gap or at the
   end of its series. Coins that join the data set later add no funds; they
   simply take part in the next rebalance. When no coin is available at a
   step, nothing is rebalanced and the portfolio is carried forward, valued at
   last known closes. The metric is
   `strategy_final_equity / index_final_equity` (values > 1.0 mean the strategy
   beat the market). The index series is precomputed in `data/meta.json` under
   `marketIndex.values`, one value per simulation step — use those values, do
   not recompute the index.
2. **Sharpe ratio.** Compute the simple hourly return of account value at each
   simulation step: `r_t = V_t / V_{t-1} - 1`. Sharpe =
   `mean(r) / stddev(r) × sqrt(8760)`, using the sample standard deviation (n
   − 1) and a risk-free rate of 0. If stddev is 0, print `N/A`.
3. **Win/loss ratio.** Each closed trade's net return = (proceeds_after_fees /
   cost_basis_after_fees) − 1. Count trades with return > 0 as wins, < 0 as
   losses. Ratio = wins / losses; zero-return trades are excluded from both
   counts. If losses = 0, print `inf`.
4. **Average gain per trade.** Mean net return across all closed trades (winners
   and losers), as a fraction of the equity deployed at entry.
5. **Average holding time.** Mean number of simulation steps (hours) from a
   trade's buy timestamp to its sell timestamp, over closed trades only.

## Output

The entire program output — metrics, simulation time, and graph — must fit in
an 80×25 character terminal: no line may exceed 80 characters, and metrics plus
graph together must not exceed 25 lines. Each implementation may choose its
own layout within that budget.

Each implementation must print:

- All five performance metrics with clear labels.
- The absolute time spent running the simulation: the wall-clock duration of
  the hourly stepping loop only, using a monotonic clock. Excluded from the
  measurement: reading coin CSVs from disk, building the simulation timeline,
  calculating the market index, and computing/printing the stats. Print as
  seconds with three decimals (e.g. `sim time: 1.234 s`).
- A text-rendered graph of account value over time (character-based line or
  bar chart), as well as coin index value, scaled to fit the remaining lines.
  Two lines in one chart, each line a seperate color. Use soft line drawing
  chars: ╭	╮	╰	╯ ─ │

Terminal-only; no GUI, no HTML.

## Testing

Every implementation must include unit tests using its language's standard or
canonical testing framework. At minimum, cover:

- RSI calculation against a fixed price fixture with known expected values.
- Simulator rules: fees applied correctly, single-position enforcement,
  buy-strength ranking and tie-breaking, behavior across data gaps.
- Metrics: Sharpe, win/loss, average gain, and holding time on a small
  hand-computed trade sequence.

## Code conventions

- Use SOLID clean code principles
- Every code block — function, method, class or impl block, and each logical
  top-level section — must be preceded by exactly one single-line comment
  naming its purpose. No block without a comment; comments never span lines.
- Use best practices and idiomatic patterns for each specific language
- Create language implementations in isolation. Do not look at or draw
  inspiration from other implementations in this repository, including the
  Deno implementation. Architecture is open and may differ between
  implementations.



## Criteria

Each language is evaluated qualitatively on:

- Dense syntax
- Data pipes
- Strong data typing
- Objects with traits or mix-ins
- Testing framework
- Console output
- Execution speed
