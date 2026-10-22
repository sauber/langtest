# Rust — RSI trading-strategy evaluation

An evaluation of an RSI(14) trading strategy over the hourly KuCoin candles in `data/`:
the strategy, the hourly simulator, five performance metrics and a text-rendered chart.

## Run the test suite

```sh
cd rust
cargo test
```

From the repository root the same works with the manifest path:

```sh
cargo test --manifest-path rust/Cargo.toml
```

## Run the evaluation

The program reads the coin CSV files and `meta.json` from `data/`, so run it from the
repository root:

```sh
cargo run --release --manifest-path rust/Cargo.toml
```

After a release build the binary can be started directly:

```sh
./rust/target/release/langtest --data-dir data
```

| Option | Meaning |
| --- | --- |
| `--data-dir <path>` | the directory that holds the coin CSV files and `meta.json` (default `data`) |
| `--no-color` | draw the chart without colour (the `NO_COLOR` environment variable does the same) |
| `-h`, `--help` | print the usage text |

## Build

```sh
cd rust
cargo build --release
```

The release profile uses `lto = "thin"` and `codegen-units = 1`; the build takes about a
minute. The only dependencies are `serde`, `serde_json` and `memchr`.

## The output

The whole report fits into 80 columns and 25 lines:

```
RSI(14) · 20 coins · 78975 steps · 2017-10-04 → 2026-10-22
equity / index      0.4532x  (equity 124,099 · index 273,799)
sharpe (hourly)     0.7664
win / loss          1.9296  (274 W / 142 L / 416 trades)
avg gain / trade    +1.0862%
avg holding time    136.19 steps
sim time: 0.001 s

╭─ equity vs market index ─────────────────────────────────────────────────────╮
...
╰──────────────────────────────────────────────────────────────────────────────╯
         2017-10-04     2020-01-19     2022-04-21     2024-07-21     2026-10-22
  ── strategy equity ══ market index
```

The two lines of the chart are drawn with different characters (`─ │` for the strategy,
`═ ║` for the index) and, unless colour is switched off, in different colours as well.

`sim time` is the wall-clock duration of the hourly stepping loop only; reading the CSV
files, building the timeline and computing the metrics are not part of it.

## The strategy

* **buy** when the RSI is at or below 30, **sell** when it is at or above 70, otherwise
  pass.
* The RSI is the 14-period Relative Strength Index with Wilder's smoothing: the first
  value is the simple average of the first 14 changes and needs 15 closes, every later
  value smooths the previous one with `(previous × 13 + change) / 14`.
* A coin with no losses has an RSI of 100, a coin with no gains an RSI of 0.
* A missing bar is skipped, never counted as a flat bar: a data gap does not change the
  RSI of the bars around it.
* The buy strength of a coin is `30 - rsi`; the deeper the oversold reading, the stronger
  the signal.

## The simulator

* Initial capital 10,000 USDT, a fee of 0.1 % on every buy and on every sell.
* The account holds zero or one coin. While a coin is held, no purchase is possible.
* The timeline is the sorted union of the bar timestamps of all coins, so a step is a real
  hour of the market even when a single coin has a gap.
* At every step the held coin is checked for a sell signal and sold at the close of its
  bar. Then, if nothing is held, the coin with the strongest buy signal is bought with
  the whole cash at the close of its bar; coins of equal strength are broken by the
  alphabetical order of their symbol.
* A coin that has no bar at the current step is carried forward and valued at its last
  known close.
* Re-entering in the same step as a sale is allowed: the sale happens first.

## The metrics

* **equity / index** — the final account value divided by the final value of the
  equal-weight market index that comes with the data set (`marketIndex.values` in
  `meta.json`); the index is not recomputed.
* **sharpe (hourly)** — the mean of the hourly returns of the account value divided by
  their sample standard deviation, times `sqrt(8760)`. `N/A` when the returns have no
  spread.
* **win / loss** — the number of winning closed trades divided by the number of losing
  ones. A trade with no return counts as neither. `inf` when no trade lost money.
* **avg gain / trade** — the mean net return of all closed trades, winners and losers
  alike, as a fraction of the capital that was deployed at entry.
* **avg holding time** — the mean number of steps between the buy and the sell of a
  closed trade. A step is an hour of the shared timeline, so a trade that spans a data
  gap still counts the hours that the gap removed.

## Architecture

The program is a pipeline of six layers. Each layer only depends on the layers below it,
and every layer is a module of the crate:

```
data/*.csv + data/meta.json
        │
        ▼  data/loader.rs ── coins, the shared timeline, the market index
   Market ──┬── strategy/ ──► SignalGrid (the signal of every coin at every step)
            │
            ▼  sim/simulator.rs ── the hourly stepping loop
      Simulation ── the equity curve and the closed trades
            │
            ▼  metrics/stats.rs ── the five metrics
       Metrics
            │
            ▼  report/ ── the metric lines and the chart
      the terminal report
```

```
src/
  lib.rs          the module tree of the crate
  domain.rs       the typed values every layer speaks in
  main.rs         the command line: parse the arguments, run the pipeline, print the report
  data/
    csv.rs        a byte-level reader for the coin CSV files
    meta.rs       the serde models of meta.json
    loader.rs     the coins, the shared timeline and the market index
  strategy/
    rsi.rs        Wilder's RSI
    signals.rs    the Strategy trait, the signal grid and the RSI strategy
  sim/
    portfolio.rs  the fee model, the open position and the closed trades
    simulator.rs  the hourly stepping loop
  metrics/
    stats.rs      the five metrics
  report/
    format.rs     the formatting of the metric values
    chart.rs      the two-series chart
    mod.rs        the report: header, metrics and chart
```

The strategy is a trait, so the simulator takes it as input: another strategy is a new
implementation of `Strategy`, nothing else changes. The signals of every coin are
computed before the loop starts, so the loop itself only reads plain arrays.

## Performance

The stepping loop is the hot path, so the layout of the data matters:

* the signals are stored step-major, one byte per coin and step, so the twenty signals of
  a step sit in one cache line;
* the closes are stored coin-major, so the held coin is read with a single indexed load;
* while a coin is held only that coin's row is touched, and only a flat account scans the
  twenty coins of a step;
* the loop allocates nothing; the trades and the equity curve are filled in place.

The loop runs over 78,975 steps in about one millisecond. The start-up is dominated by
reading the 91 MB of CSV files, which is I/O bound and therefore not part of `sim time`.

## Tests

| File | What it covers |
| --- | --- |
| `tests/rsi.rs` | the RSI against a fixed price fixture with known values, the gaps, the edge cases |
| `tests/strategy.rs` | the RSI thresholds and the buy strength |
| `tests/simulator.rs` | the fees, the single position, the ranking, the tie-break, the data gaps, the sale and the re-entry in one step |
| `tests/metrics.rs` | the Sharpe ratio, the win/loss counts, the average gain and the holding time on hand-computed trades |
| `tests/report.rs` | the width and the height of the report, the two series of the chart |
| `tests/csv.rs` | the CSV reader and its error cases |
