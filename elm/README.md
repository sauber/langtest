# Elm — trading strategy evaluator

Elm implementation of the RSI(14) trading-strategy evaluator. It loads the shared market data from
`../data`, simulates the strategy, and prints the five performance metrics, the simulation time and a
character chart of the account value and the market index.

Elm has no file system and no standard output of its own, so the program is a *port module* that is
driven by a small Node host (`runner.js`). The host reads the CSV files and hands them to the Elm
program over ports; the Elm program owns the parsing, the RSI, the simulation, the metrics and the
rendering of the report.

## How to run the test suite

```sh
cd elm
npm install     # once, it installs the elm-test runner
npm test
```

This runs the unit tests of `tests/` with [`elm-test`](https://github.com/rtfeldman/node-test-runner)
and `elm-explorations/test` for the expectations. The tests need no market data on disk: they build
synthetic markets in memory.

The suite covers the RSI against a fixed price fixture, the rules of the simulator (fees, the single
position, the ranking and the tie break of the buy signals, data gaps), the metrics on a hand
computed trade sequence, the market model and the CSV parser.

The Elm compiler `elm` (0.19.3) and Node.js (18 or newer) have to be on the `PATH`.

## How to run the evaluation

```sh
cd elm
npm start
```

The script compiles the Elm program and runs it against the CSV files of `../data` (the default
location, resolved relative to the host, so the command works from any working directory). A
different data directory can be passed explicitly:

```sh
node runner.js --data=/path/to/csv-directory
```

## Build and quality commands

```sh
npm run build   # elm make src/Main.elm --optimize --output=elm.js — optimised JavaScript
npm test        # elm-test                                             — unit tests
npm start       # npm run build && node runner.js                      — the evaluation
```

`elm make` reports every type error and every shadowing warning; the code base is free of both.
`elm-test` type checks the test modules before it runs them.

The dependency manifest keeps `elm/html` although no module imports it: the Elm compiler needs
`elm/json` for every port module, and its dependency solver only accepts `elm/json` as an indirect
dependency, so `elm/html` is the provider that makes it visible.

## What the program does

1. **Load** — the host lists the `*.csv` files of the data directory and sends them one by one
   (`runner.js`). `Csv.elm` parses the rows and keeps the timestamp and the close price of every
   row; a file whose header or whose rows do not match the expected format is refused.
2. **Market** — `Market.elm` builds the simulation timeline as the sorted union of all bar
   timestamps and aligns every coin to that timeline. The steps of the timeline are the hours of the
   simulation, so a coin with a missing row simply has no candle at that step.
3. **Signal** — `Strategy.elm` holds the strategy as a swappable value: a name and a function that
   turns the close prices of a coin into its signals. The shipped strategy (`rsiStrategy`) computes
   Wilder's RSI(14) with `Rsi.elm` and turns it into `buy` (RSI ≤ 30), `sell` (RSI ≥ 70) or
   `pass`. The buy strength of a coin is `30 - RSI`, so a lower RSI means a stronger signal. The
   first 14 bars of a coin have no RSI and therefore no signal.
4. **Simulate** — `Events.elm` aligns every candle of every coin with its signal, `Simulator.elm`
   steps through the timeline once, hourly. It sells the held coin on a sell signal, then buys the
   coin with the strongest buy signal with all available cash when nothing is held. Ties are broken
   alphabetically. The account is valued after every step as cash plus the quantity of the held coin
   times its last known close.
5. **Measure** — `Index.elm` builds the equal-weighted buy-and-hold index, `Metrics.elm` computes
   the equity-to-index ratio, the annualised hourly Sharpe ratio, the win/loss ratio, the average
   gain per trade and the average holding time.
6. **Report** — `Chart.elm` and `Report.elm` render the metrics and a two-colour character chart
   that fits into an 80×25 terminal.

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
  then smoothed with Wilder's formula.
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

The whole report is 25 lines high and at most 78 visible columns:

```
RSI(14) · 20 coins · 78960 hourly steps · 2017-10-04 → 2026-10-21
equity / index     1.7468x  (equity 85,539 · index 48,970)
sharpe (hourly)    0.7262
win / loss         1.9716  (278 W / 141 L / 419 trades)
avg gain / trade   +0.9902%
avg holding time   134.92 h
sim time: 0.201 s
╭────────────────────────────────────────────────────────────────────────────╮
│111.7k┤                                                                     │
│      ┤                                                              ╰      │
│      ┤                                                            ╰─       │
│      ┤                                                                    ╰│
...
╰─ 2017-10-04 ─────────────────────────────────────────────────── 2026-10-21 ╯
● strategy equity (cyan)   ● market index (magenta, shared axis)
```

`sim time` measures only the hourly stepping loop with a monotonic clock. Reading the CSV files,
building the timeline, applying the strategy, computing the market index and rendering the report
are excluded from that measurement.

## Reference values

On the shipped data set (20 coins, 78,960 hourly steps from 2017-10-04 to 2026-10-21) the evaluation
produces:

| Metric                  | Value                                     |
| ----------------------- | ----------------------------------------- |
| Equity / market index   | 1.7468x                                   |
| Sharpe ratio (hourly)   | 0.7262                                    |
| Win / loss ratio        | 1.9716 (278 wins, 141 losses, 419 trades) |
| Average gain per trade  | +0.9902 %                                 |
| Average holding time    | 134.92 h                                  |
| Final equity            | 85,539 USDT                               |
| Market index at the end | 48,970 USDT                               |

The numbers were cross-checked against the reference implementation of the same specification.

## Project layout

```
elm/
├── elm.json               project configuration and the package dependencies
├── package.json           the npm scripts
├── runner.js              Node host: reads the data files and drives the Elm program
├── src/
│   ├── Domain.elm         the shared data types
│   ├── Csv.elm            the parser of the market data files
│   ├── Market.elm         the shared timeline and the coins aligned to it
│   ├── Rsi.elm            Wilder's relative strength index
│   ├── Strategy.elm       the swappable strategy and its signals
│   ├── Events.elm         the candles of the market with their signals
│   ├── Simulator.elm      the hourly stepping loop and the trades
│   ├── Index.elm          the equal-weighted buy-and-hold index
│   ├── Metrics.elm        the performance metrics
│   ├── Chart.elm          the character chart
│   ├── Format.elm         the number formatting
│   ├── Report.elm         the report layout
│   └── Main.elm           the port module and its phases
└── tests/                 unit tests for RSI, simulator, metrics, market and CSV
```
