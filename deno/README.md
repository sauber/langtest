# Deno (TypeScript) — trading strategy evaluator

Reference implementation of the RSI(14) trading-strategy evaluator. It loads the shared market data
from `../data`, simulates the strategy, and prints the five performance metrics, the simulation time
and a character chart of the account value and the market index.

## How to run the test suite

```sh
cd deno
deno task test
```

This runs the unit tests of `test/` with the built-in Deno test runner (`Deno.test`) and
`@std/assert` for assertions. The tests need no market data on disk: they build synthetic markets in
memory.

## How to run the evaluation

```sh
cd deno
deno task start
```

The program reads the CSV files of `../data` (the default location, resolved relative to the module,
so the command works from any working directory) and prints the report to the terminal. A different
data directory can be passed explicitly:

```sh
deno task start --data=/path/to/csv-directory
```

## Build and quality commands

Deno needs no build step; the TypeScript is type checked and executed directly.

```sh
deno task check   # deno check src/main.ts test/  — static type check
deno task lint    # deno lint                      — lint rules
deno task fmt     # deno fmt                       — formatting (deno fmt --check to verify)
```

## What the program does

1. **Load** — every `*.csv` file of the data directory is streamed, and the timestamp and close
   price of every row are collected (`src/data/`). The simulation timeline is the sorted union of
   all bar timestamps; every coin is aligned to that timeline, and the last known close of each coin
   is forward filled so gaps can be valued.
2. **Signal** — `RsiStrategy` (`src/strategy/`) computes Wilder's RSI(14) on the close prices of
   each coin and turns it into `buy` (RSI ≤ 30), `sell` (RSI ≥ 70) or `pass`. The buy strength of a
   coin is `30 - RSI`, so a lower RSI means a stronger signal. The first 14 bars of a coin have no
   RSI and therefore no signal.
3. **Simulate** — `Simulator` (`src/sim/`) steps through the timeline once, hourly. It sells the
   held coin on a sell signal, then buys the coin with the strongest buy signal with all available
   cash when nothing is held. Ties are broken alphabetically. The account is valued after every step
   as cash plus the quantity of the held coin times its last known close.
4. **Measure** — `src/metrics/` computes the equity-to-index ratio, the annualised hourly Sharpe
   ratio, the win/loss ratio, the average gain per trade and the average holding time.
5. **Report** — `src/report/` renders the metrics and a two-colour character chart that fits into an
   80×25 terminal.

## Rules and conventions

| Parameter             | Value                                                             |
| --------------------- | ----------------------------------------------------------------- |
| Initial capital       | 10,000 USDT                                                       |
| Fee                   | 0.1 % on every buy and every sell                                 |
| Position limit        | one coin at a time, no second purchase while holding              |
| Buy quantity          | `cash / (close × 1.001)`, fractional units allowed                |
| Sell proceeds         | `quantity × close × 0.999`                                        |
| RSI                   | 14 periods, Wilder smoothing, computed on close prices            |
| Buy / sell thresholds | RSI ≤ 30 / RSI ≥ 70                                               |
| Sharpe annualisation  | `sqrt(8760)` hourly periods per year, sample deviation (n − 1)    |
| Market index          | equal weight, 10,000 / 20 USDT per coin at its first bar, no fees |

## Resolved ambiguities

The specification leaves a few points open. This implementation resolves them as follows, and the
unit tests pin every one of them down.

- **RSI seeding** — the first RSI value appears at bar index 14, that is after 14 price changes (15
  closes). The average gain and loss are seeded with the simple mean of the first 14 changes and
  then smoothed with Wilder's formula. Seeding one bar earlier produces the same metrics on the
  shipped data.
- **Flat markets** — when the average loss is zero the RSI is 100, when the average gain is zero it
  is 0 (the StockCharts convention).
- **Gaps** — a coin without a bar at a timestamp cannot be traded. Its position is carried forward
  and valued with the last known close, which is the close of the most recent bar at or before that
  timestamp.
- **Signal of a held coin** — only the coin that is actually held is checked for a sell signal. A
  sell may be followed by a new purchase in the same step, including a purchase of another coin.
- **Holding time** — the number of simulation steps between the entry and the exit of a trade, so
  one step is one hour of the simulation timeline.
- **Open position** — a position that is still open at the end of the simulation counts towards the
  final equity but not towards the win/loss ratio, the average gain or the average holding time.
- **Break-even trades** — a trade with a net return of exactly zero counts neither as a win nor as a
  loss. With no losing trade the win/loss ratio is reported as `inf`.
- **Chart axis** — the equity curve and the market index share one linear axis, so the two series
  are directly comparable. The index is the flatter of the two lines here and is drawn in magenta.

## Output

The whole report is 23 lines wide and at most 78 visible columns:

```
RSI(14) · 20 coins · 78,949 hourly steps · 2017-10-04 → 2026-10-20
equity / index       0.3611x  (equity 19,295 · index 53,432)
sharpe (hourly)       0.5811
win / loss            1.8592  (264 W / 142 L / 406 trades)
avg gain / trade    +0.7751%
avg holding time    144.43 h
sim time: 0.043 s
╭────────────────────────────────────────────────────────────────────────────╮
│   72.0k┤                                                             ╰╮      │
│        ┤                             ╰─╮                         ╰╯│      │
...
╰ ─ 2017-10-04 ───────────────────────────────────────────────── 2026-10-20 ╯
● strategy equity (cyan)   ● market index (magenta, shared axis)
```

`sim time` measures only the hourly stepping loop with a monotonic clock. Reading the CSV files,
building the timeline, computing the market index and rendering the report are excluded from that
measurement.

## Reference values

On the shipped data set (20 coins, 78,949 hourly steps from 2017-10-04 to 2026-10-20) the evaluation
produces:

| Metric                  | Value                                     |
| ----------------------- | ----------------------------------------- |
| Equity / market index   | 0.3611x                                   |
| Sharpe ratio (hourly)   | 0.5811                                    |
| Win / loss ratio        | 1.8592 (264 wins, 142 losses, 406 trades) |
| Average gain per trade  | +0.7751 %                                 |
| Average holding time    | 144.43 h                                  |
| Final equity            | 19,295 USDT                               |
| Market index at the end | 53,432 USDT                               |

The numbers were cross-checked against an independent implementation of the same specification.

## Project layout

```
deno/
├── deno.json            project configuration, tasks and the import map
├── src/
│   ├── domain/types.ts  the shared data types
│   ├── data/            CSV parsing, streaming scanner and timeline alignment
│   ├── strategy/        Wilder RSI and the RSI strategy
│   ├── sim/             portfolio accounting and the hourly simulator
│   ├── metrics/         market index and the performance statistics
│   ├── report/          character chart and report rendering
│   └── main.ts          entry point
└── test/                unit tests for RSI, simulator, metrics and report
```
