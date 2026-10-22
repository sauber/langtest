# Raku implementation

Rakudo implementation of the trading-strategy evaluator. It reads the shared
CSV files in `../data`, runs the hourly simulation, prints the five metrics,
the timed simulation duration and a two-series terminal chart.

## Run the test suite

From this `raku/` directory:

```sh
prove -e raku -v t/
```

A single test file can also be run directly:

```sh
raku -Ilib t/03-strategy.t
```

## Run the evaluation

From this `raku/` directory:

```sh
raku langtest.raku
```

Or from the repository root:

```sh
raku raku/langtest.raku
```

The program locates `data/` relative to its own path, so it works from either
location without arguments.

## Build

There is no build step: Raku is interpreted. Rakudo `v2026.09` or newer is
recommended. Only core Raku and its bundled `Test` and `NativeCall` modules are
used; there are no third-party dependencies.

A compile check of every module and the entry point:

```sh
raku -Ilib -c lib/LangTest/Num.rakumod
raku -Ilib -c lib/LangTest/Json.rakumod
raku -Ilib -c lib/LangTest/Clock.rakumod
raku -Ilib -c lib/LangTest/Strategy.rakumod
raku -Ilib -c lib/LangTest/Metadata.rakumod
raku -Ilib -c lib/LangTest/Market.rakumod
raku -Ilib -c lib/LangTest/Simulator.rakumod
raku -Ilib -c lib/LangTest/Metrics.rakumod
raku -Ilib -c lib/LangTest/Chart.rakumod
raku -Ilib -c lib/LangTest/Format.rakumod
raku -Ilib -c langtest.raku
```

## Architecture

| Module | Responsibility |
| --- | --- |
| `LangTest::Num` | Fast plain-decimal parser with a precomputed power-of-ten table. |
| `LangTest::Json` | Small recursive-descent JSON reader with a cursor and no dependencies. |
| `LangTest::Clock` | `MonotonicClock` role plus a `clock_gettime(CLOCK_MONOTONIC)` implementation. |
| `LangTest::Metadata` | Typed view of `data/meta.json`, including the precomputed market index. |
| `LangTest::Market` | CSV loading and the flat, step-indexed bar store used by the hot loop. |
| `LangTest::Strategy` | `Strategy` role, `Signal` enum and the RSI-14 strategy implementation. |
| `LangTest::Simulator` | Single-position hourly engine and its `Trade` / `SimulationResult` value objects. |
| `LangTest::Metrics` | Sharpe ratio, win/loss, average gain, holding time and market comparison. |
| `LangTest::Chart` | Framed two-series line chart drawn with soft box characters and ANSI colours. |
| `LangTest::Format` | 80x25-aware report layout and human-readable number formatting. |

### Strategy

`RsiStrategy does Strategy` computes Wilder-smoothed RSI-14 on closes. The
first value appears at the fourteenth close (index 13): the seed averages the
thirteen price changes, and every later value applies Wilder's recursive
smoothing. Bars below RSI 30 emit `Buy`, bars at or above 70 emit `Sell`, and
everything else passes. Buy strength is `30 - RSI`.

### Simulator

The market is flattened into parallel native arrays (`int` / `num`):
per-bar step, coin, close, signal and strength, plus per-coin cursor bounds and
a step-major index. The timed loop walks the shared timeline once, advances
only the held coin's cursor, sells first when its bar carries a sell signal,
then looks up the highest buy strength at that step for a possible re-entry.
Equity is recorded after the trade rules. Only this loop is measured; the
injected `MonotonicClock` keeps the timer testable.

### Output

The report uses seven metric lines and a thirteen-line chart (legend, frame and
ten plot rows). Every line stays within 80 visible columns and the total is
20 lines, inside the 25-line budget. The chart draws the strategy in green and
the market index in cyan over a framed `╭ ╮ ╰ ╯ ─ │` grid, with compact
vertical scale labels.

### Tests

`t/` covers the numeric parser, JSON reader, RSI fixture values, signal
thresholds, fee handling, single-position enforcement, buy-strength ranking,
alphabetical tie-breaking, data gaps, same-step re-entry, all five metrics on
hand-computed trades, chart geometry/width, and the report layout. A
`FakeClock` supplies deterministic monotonic readings to the simulator.
