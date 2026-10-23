# Elixir Implementation

Hourly RSI-14 mean-reversion evaluation over the KuCoin 1-hour candle data set.
The project has no external dependencies, so Hex is not required.

## Run the test suite

```sh
cd elixir
mix test
```

## Run the evaluation

From the `elixir/` directory (the data directory is found automatically):

```sh
mix langtest
```

Pass an explicit data directory when needed:

```sh
mix langtest --data ../data
```

The escript build can also be run from the repository root:

```sh
./elixir/langtest
```

## Build

```sh
cd elixir
mix escript.build
```

This produces `elixir/langtest`. The escript resolves `data/` from the current
working directory or its parent, so it can be started from either the repository
root or the `elixir/` directory.

## Design

- `Langtest.Meta` and `Langtest.JSON` decode the generated meta file with a
  small recursive-descent JSON decoder, avoiding external dependencies.
- `Langtest.CSV` extracts the first and sixth columns from each candle row.
- `Langtest.RSI` implements Wilder's 14-period smoothing incrementally. The
  first RSI value is emitted after 14 price changes, so the first 14 bars have
  no signal.
- `Langtest.Strategy.RSI` is a `Langtest.Strategy` behaviour implementation:
  buy at RSI <= 30, sell at RSI >= 70, strength = `30 - RSI`.
- `Langtest.MarketData` computes signals once per bar, merges the 20 sorted bar
  lists into the union timeline, and freezes everything into tuples:
  per-step closes and signals, plus the strongest precomputed buy candidate.
- `Langtest.Simulator` runs a pure tail-recursive loop with O(1) tuple lookups,
  one position at a time, fees on both sides, gap carry-forward, and same-step
  re-entry after a sell. Only this loop is timed with a monotonic clock.
- `Langtest.Metrics` computes the market-index ratio, annualized Sharpe ratio
  (Welford, sample standard deviation), win/loss ratio, average trade gain, and
  average holding time.
- `Langtest.Graph` and `Langtest.Report` render the two colored series with soft
  box-drawing characters inside the 80x25 terminal budget.

The index series is read from `data/meta.json`; it is never recomputed. The
printed sim time excludes CSV parsing, timeline construction, index loading,
and statistics.

## Tests

`mix test` covers RSI fixture values, CSV/JSON parsing, timeline merging and
gaps, alphabetical buy-strength tie-breaking, fee arithmetic, single-position
enforcement, gap valuation, same-step re-entry, all metrics, chart framing, and
the terminal width/line budget.
