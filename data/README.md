# Market data — `data/`

**One-time analysis of the downloaded KuCoin 1-hour candles.** Every number below was measured
directly from the CSV files. Read this document instead of re-scanning `data/` — it settles every
question that comes up while implementing or reviewing an evaluator.

The dataset is produced by `download_kucoin.ts` (repo root). It is *not* checked in: `.gitignore`
excludes the CSVs but keeps this file.

---

## 1. Inventory

| Item | Value |
| --- | --- |
| Files | 20 × `<SYMBOL>-USDT.csv` |
| Total size | 95,436,859 bytes (91.0 MiB / 95.4 MB) |
| Total data rows | 1,031,357 (plus 20 header lines = 1,031,377 lines) |
| Bar interval | 1 hour |
| Quote currency | USDT for every symbol |
| Symbols | AAVE, AVAX, BNB, BTC, DOT, ETH, HYPE, INJ, KCS, LINK, LTC, NEAR, PIEVERSE, SOL, SUI, TAO, UNI, XMR, XRP, ZEC (all `-USDT`) |

---

## 2. File format

Identical for all 20 files:

| Property | Value |
| --- | --- |
| Encoding | UTF-8, **no BOM** |
| Line ending | `LF` (`\n`) — no `CRLF` anywhere |
| Final newline | **Yes** — every file ends with `\n` |
| Header | `timestamp,datetime,open,high,low,close,volume,turnover` (byte-identical in all 20 files) |
| Fields per row | exactly **8** — never 7, never 9 |
| Quoting | none — no field is ever wrapped in `"` and no field contains a comma |
| Empty fields | none |
| Row order | strictly ascending by `timestamp` |
| Duplicate timestamps | none (0 in every file) |

---

## 3. Schema

| # | Column | Type | Unit | Notes |
| --- | --- | --- | --- | --- |
| 0 | `timestamp` | integer | Unix epoch **seconds**, UTC | Candle **open** time. Always an exact multiple of `3600`. |
| 1 | `datetime` | string | — | ISO-8601 `YYYY-MM-DDTHH:MM:SS.000Z` (UTC, milliseconds always `.000`). |
| 2 | `open` | number | USDT | Candle open price. |
| 3 | `high` | number | USDT | Candle high price. |
| 4 | `low` | number | USDT | Candle low price. |
| 5 | `close` | number | USDT | Candle close price. **The only price the evaluator uses.** |
| 6 | `volume` | number | base coin | Traded volume in the base coin. |
| 7 | `turnover` | number | USDT | Traded value in the quote coin (`≈ volume × close`). |

**`datetime` is redundant.** For all 1,031,357 rows the ISO string equals
`strftime("%Y-%m-%dT%H:%M:%S.000Z", gmtime(timestamp))` — **0 mismatches**. An implementation may
safely ignore the column and derive everything from `timestamp`.

**Only `timestamp` and `close` are needed** by the evaluator (RSI, signals, execution prices,
mark-to-market, and the buy-and-hold index).

---

## 4. Number formatting (parsers must handle both forms)

`close` values appear in two shapes, so a parser that assumes a decimal point will break:

| Shape | Example | Count |
| --- | --- | ---: |
| Integer (no `.`) | `40`, `4307`, `126000` | 16,535 |
| Decimal | `34.385`, `0.0740365`, `126000.5` | 1,014,822 |
| Scientific notation | — | **0** |

Decimal-digit histogram of the 1,014,822 decimal-form closes:

| Digits after `.` | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Rows | 83,885 | 194,150 | 412,759 | 209,911 | 84,478 | 28,983 | 31 | 625 |

`volume` and `turnover` are also mixed integer/decimal and reach **20 decimal places**
(e.g. `6230.88208458603620574037`); they are not used by the evaluator, but a generic CSV reader
must not assume a fixed scale. No value is ever empty or `NaN`/`Inf`.

---

## 5. Timestamp format

* `timestamp` — integer Unix seconds, **UTC**, candle **open** time.
* Every timestamp is an exact multiple of `3600` (verified for all 1,031,357 rows) → the series is
  a strict hourly grid, never offset by minutes or seconds.
* `datetime` — `YYYY-MM-DDTHH:MM:SS.000Z`, e.g. `2017-10-04T04:00:00.000Z`.

Earliest and latest bars in the whole dataset:

| | Timestamp | ISO |
| --- | ---: | --- |
| Global first | 1507089600 | `2017-10-04T04:00:00Z` |
| Global last | 1792512000 | `2026-10-20T16:00:00Z` |

---

## 6. Per-coin coverage

`span` = hours between the coin's own first and last bar (inclusive). `missing` = hours inside
that span with no bar. `gaps` = number of discontinuous stretches. `flat` = longest run of
identical consecutive closes. `zero-vol` = bars with `volume == 0`.

| symbol | rows | first bar (UTC) | last bar (UTC) | span h | missing h | coverage | gaps | max gap | flat | zero-vol | close min | close max |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| AAVE-USDT | 52542 | 2020-10-22 10:00 | 2026-10-20 15:00 | 52542 | 0 | 100.000% | 0 | 0 h | 6 | 15 | 26.013 | 657.197 |
| AVAX-USDT | 49326 | 2021-03-05 10:00 | 2026-10-20 15:00 | 49326 | 0 | 100.000% | 0 | 0 h | 4 | 10 | 5.876 | 143.978 |
| BNB-USDT | 64327 | 2019-06-19 10:00 | 2026-10-20 16:00 | 64327 | 0 | 100.000% | 0 | 0 h | 6 | 122 | 7.693 | 1369.43 |
| BTC-USDT | 78886 | 2017-10-04 04:00 | 2026-10-20 15:00 | 79284 | 398 | 99.498% | 62 | 68 h | 18 | 31 | 3171.35 | 126000 |
| DOT-USDT | 54023 | 2020-08-21 17:00 | 2026-10-20 15:00 | 54023 | 0 | 100.000% | 0 | 0 h | 6 | 16 | 0.7286 | 55.0351 |
| ETH-USDT | 78773 | 2017-10-04 04:00 | 2026-10-20 15:00 | 79284 | 511 | 99.355% | 96 | 92 h | 18 | 33 | 82.2337 | 4935.71 |
| HYPE-USDT | 16370 | 2024-12-07 15:00 | 2026-10-20 16:00 | 16370 | 0 | 100.000% | 0 | 0 h | 2 | 0 | 9.477 | 97.533 |
| INJ-USDT | 43831 | 2021-10-20 10:00 | 2026-10-20 16:00 | 43831 | 0 | 100.000% | 0 | 0 h | 4 | 6 | 1.139 | 52.368 |
| KCS-USDT | 78265 | 2017-10-18 04:00 | 2026-10-20 16:00 | 78949 | 684 | 99.134% | 483 | 10 h | 18 | 39 | 0.0740365 | 28.694 |
| LINK-USDT | 54054 | 2020-08-20 10:00 | 2026-10-20 15:00 | 54054 | 0 | 100.000% | 0 | 0 h | 7 | 15 | 4.9765 | 52.2418 |
| LTC-USDT | 75501 | 2018-01-28 10:00 | 2026-10-20 15:00 | 76494 | 993 | 98.702% | 701 | 8 h | 18 | 231 | 11.2486 | 409.424 |
| NEAR-USDT | 46302 | 2021-07-09 10:00 | 2026-10-20 15:00 | 46302 | 0 | 100.000% | 0 | 0 h | 4 | 16 | 0.94 | 20.2985 |
| PIEVERSE-USDT | 3631 | 2026-05-22 10:00 | 2026-10-20 16:00 | 3631 | 0 | 100.000% | 0 | 0 h | 2 | 4 | 0.5795 | 1.9216 |
| SOL-USDT | 45678 | 2021-08-04 10:00 | 2026-10-20 15:00 | 45678 | 0 | 100.000% | 0 | 0 h | 4 | 7 | 8.278 | 286.279 |
| SUI-USDT | 30388 | 2023-05-03 12:00 | 2026-10-20 15:00 | 30388 | 0 | 100.000% | 0 | 0 h | 4 | 3 | 0.36447 | 5.344 |
| TAO-USDT | 24847 | 2023-12-20 09:00 | 2026-10-20 15:00 | 24847 | 0 | 100.000% | 0 | 0 h | 2 | 0 | 144.63 | 752.33 |
| UNI-USDT | 53384 | 2020-09-17 08:00 | 2026-10-20 15:00 | 53384 | 0 | 100.000% | 0 | 0 h | 6 | 15 | 1.7907 | 44.6678 |
| XMR-USDT | 48872 | 2021-03-24 08:00 | 2026-10-20 15:00 | 48872 | 0 | 100.000% | 0 | 0 h | 4 | 10 | 99.76 | 788.91 |
| XRP-USDT | 68368 | 2018-12-03 16:00 | 2026-10-20 15:00 | 69072 | 704 | 98.981% | 345 | 12 h | 18 | 268 | 0.1195 | 3.65272 |
| ZEC-USDT | 63989 | 2019-07-03 11:00 | 2026-10-20 15:00 | 63989 | 0 | 100.000% | 0 | 0 h | 14 | 1299 | 16.299 | 1682.7 |

### 6.1 Coin start / end positions on the shared timeline

Useful for asserting that an implementation aligned coins to the right timeline steps
(`step` = 0-based index into the union timeline of §7, 78,949 steps):

| symbol | first step | last step | | symbol | first step | last step |
| --- | ---: | ---: | --- | --- | ---: | ---: |
| BTC-USDT | 0 | 78947 | | NEAR-USDT | 32646 | 78947 |
| ETH-USDT | 0 | 78947 | | INJ-USDT | 35118 | 78948 |
| KCS-USDT | 19 | 78948 | | SUI-USDT | 48560 | 78947 |
| LTC-USDT | 2454 | 78947 | | TAO-USDT | 54101 | 78947 |
| XRP-USDT | 9876 | 78947 | | HYPE-USDT | 62579 | 78948 |
| ZEC-USDT | 14959 | 78947 | | PIEVERSE-USDT | 75318 | 78948 |
| BNB-USDT | 14622 | 78948 | | DOT-USDT | 24925 | 78947 |
| XMR-USDT | 30076 | 78947 | | LINK-USDT | 24894 | 78947 |
| AVAX-USDT | 29622 | 78947 | | UNI-USDT | 25564 | 78947 |
| SOL-USDT | 33270 | 78947 | | AAVE-USDT | 26406 | 78947 |

The final step is `78948` (= `2026-10-20T16:00:00Z`) for the five coins BNB, HYPE, INJ, KCS
and PIEVERSE; the other fifteen stop at `78947` (`2026-10-20T15:00:00Z`).

---

## 7. The shared simulation timeline

The specification defines the timeline as the **sorted union of every coin's bar timestamps**.
Measured on this dataset:

| Item | Value |
| --- | --- |
| Distinct timestamps in the union | **78,949** |
| First step | `2017-10-04T04:00:00Z` (1507089600) |
| Last step | `2026-10-20T16:00:00Z` (1792512000) |
| Wall-clock span | 79,285 hours |
| Hours inside the span with **no** coin at all | **336**, in **28** separate holes |
| Consecutive steps 1 h apart | 78,920 of 78,948 |
| Mean coins reporting per step | 13.064 (min 1, max 20) |

> **The timeline is *not* a continuous hourly series.** It contains 28 holes where *no* coin has a
> bar, all of them in the 2017-10 → 2018-01 era when only BTC, ETH and KCS existed. Consequently
> **1 timeline step ≠ 1 wall-clock hour**, and "average holding time in hours" is really a count of
> timeline steps. Never derive a step index from `(timestamp - first) / 3600` — map timestamps to
> steps instead.

Coins reporting per step (histogram of the 78,949 steps):

| Coins | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Steps | 63 | 393 | 3,098 | 7,321 | 3,748 | 337 | 9,935 | 31 | 639 | 842 | 3,216 | 454 | 2,570 | 624 | 1,848 | 13,442 | 5,541 | 8,478 | 12,739 | 3,630 |

### 7.1 The 28 holes in the union timeline

Between the two listed steps, no coin of any symbol reports a bar.

| # | After | Before | Missing hours |
| ---: | --- | --- | ---: |
| 1 | 2017-10-04 04:00 | 2017-10-04 09:00 | 4 |
| 2 | 2017-10-04 09:00 | 2017-10-05 13:00 | 27 |
| 3 | 2017-10-05 13:00 | 2017-10-06 00:00 | 10 |
| 4 | 2017-10-06 00:00 | 2017-10-07 02:00 | 25 |
| 5 | 2017-10-07 02:00 | 2017-10-07 09:00 | 6 |
| 6 | 2017-10-07 09:00 | 2017-10-07 12:00 | 2 |
| 7 | 2017-10-07 12:00 | 2017-10-08 06:00 | 17 |
| 8 | 2017-10-08 06:00 | 2017-10-09 03:00 | 20 |
| 9 | 2017-10-09 05:00 | 2017-10-09 13:00 | 7 |
| 10 | 2017-10-09 13:00 | 2017-10-12 09:00 | 67 |
| 11 | 2017-10-12 10:00 | 2017-10-13 16:00 | 29 |
| 12 | 2017-10-13 16:00 | 2017-10-14 12:00 | 19 |
| 13 | 2017-10-14 12:00 | 2017-10-15 12:00 | 23 |
| 14 | 2017-10-15 12:00 | 2017-10-16 06:00 | 17 |
| 15 | 2017-10-16 06:00 | 2017-10-17 03:00 | 20 |
| 16 | 2017-10-17 03:00 | 2017-10-18 04:00 | 24 |
| 17 | 2017-10-18 04:00 | 2017-10-18 06:00 | 1 |
| 18 | 2017-10-18 06:00 | 2017-10-18 09:00 | 2 |
| 19 | 2017-10-18 10:00 | 2017-10-18 14:00 | 3 |
| 20 | 2017-10-21 17:00 | 2017-10-21 19:00 | 1 |
| 21 | 2017-10-21 19:00 | 2017-10-21 22:00 | 2 |
| 22 | 2017-10-22 00:00 | 2017-10-22 02:00 | 1 |
| 23 | 2017-11-12 23:00 | 2017-11-13 02:00 | 2 |
| 24 | 2017-11-20 22:00 | 2017-11-21 02:00 | 3 |
| 25 | 2017-12-01 15:00 | 2017-12-01 17:00 | 1 |
| 26 | 2017-12-23 07:00 | 2017-12-23 09:00 | 1 |
| 27 | 2017-12-24 06:00 | 2017-12-24 08:00 | 1 |
| 28 | 2018-01-04 16:00 | 2018-01-04 18:00 | 1 |

Total: 336 hours.

### 7.2 Coins alive over time (clean segments)

The market grows monotonically from 2019-06-19 onward (before that the early era is fragmented
by the holes of §7.1):

| From (UTC) | To (UTC) | Coins |
| --- | --- | ---: |
| 2017-10-04 | 2017-10-18 | 2 (BTC, ETH) — heavily fragmented by the holes above |
| 2017-10-18 | 2019-06-19 | 3 (BTC, ETH, KCS) |
| 2019-06-19 | 2019-07-03 | 6 |
| 2019-07-03 | 2020-08-20 | 7 |
| 2020-08-20 | 2020-08-21 | 8 |
| 2020-08-21 | 2020-09-17 | 9 |
| 2020-09-17 | 2020-10-22 | 10 |
| 2020-10-22 | 2021-03-05 | 11 |
| 2021-03-05 | 2021-03-24 | 12 |
| 2021-03-24 | 2021-07-09 | 13 |
| 2021-07-09 | 2021-08-04 | 14 |
| 2021-08-04 | 2021-10-20 | 15 |
| 2021-10-20 | 2023-05-03 | 16 |
| 2023-05-03 | 2023-12-20 | 17 |
| 2023-12-20 | 2024-12-07 | 18 |
| 2024-12-07 | 2026-05-22 | 19 |
| 2026-05-22 | 2026-10-20 | 20 |

The market index therefore **ramps up**: a coin listed in 2026 only contributes to the index from
its own first bar, so the index value is not a constant-20-coin basket over the whole window.

---

## 8. Data gaps

**15 of the 20 coins are perfectly contiguous** inside their own range (0 missing hours, 0 gaps):
AAVE, AVAX, BNB, DOT, HYPE, INJ, LINK, NEAR, PIEVERSE, SOL, SUI, TAO, UNI, XMR, ZEC.

Only **5 coins** have gaps — all of them among the earliest-listed symbols:

| symbol | gaps | missing hours | max gap | gap-length histogram (hours → count) |
| --- | ---: | ---: | ---: | --- |
| BTC-USDT | 62 | 398 | 68 h | 2→33, 3→8, 4→6, 5→2, 6→1, 8→1, 10→1, 11→1, 20→1, 24→1, 26→1, 27→1, 28→1, 30→1, 39→2, 68→1 |
| ETH-USDT | 96 | 511 | 92 h | 2→52, 3→15, 4→12, 5→7, 6→1, 7→1, 10→2, 21→1, 31→1, 57→1, 69→1, 72→1, 92→1 |
| KCS-USDT | 483 | 684 | 10 h | 2→366, 3→70, 4→25, 5→13, 6→6, 7→2, 10→1 |
| LTC-USDT | 701 | 993 | 8 h | 2→508, 3→125, 4→47, 5→16, 6→1, 7→3, 8→1 |
| XRP-USDT | 345 | 704 | 12 h | 2→179, 3→83, 4→37, 5→18, 6→14, 7→4, 8→4, 9→3, 10→1, 11→1, 12→1 |

`gap-length histogram` counts *holes* of the given size: "2→33" means 33 separate 2-hour holes.

Largest single holes (all but three fall in the Oct 2017 bootstrap era):

| symbol | From | To | Missing |
| --- | --- | --- | ---: |
| ETH-USDT | 2017-10-12 10:00 | 2017-10-16 06:00 | 92 h |
| ETH-USDT | 2017-10-04 09:00 | 2017-10-07 09:00 | 72 h |
| ETH-USDT | 2017-10-09 13:00 | 2017-10-12 10:00 | 69 h |
| BTC-USDT | 2017-10-09 13:00 | 2017-10-12 09:00 | 68 h |
| ETH-USDT | 2017-10-16 06:00 | 2017-10-18 15:00 | 57 h |
| BTC-USDT | 2017-10-15 12:00 | 2017-10-17 03:00 | 39 h |
| BTC-USDT | 2017-10-07 12:00 | 2017-10-09 03:00 | 39 h |
| BTC-USDT | 2017-10-12 10:00 | 2017-10-13 16:00 | 30 h |
| XRP-USDT | 2019-01-24 06:00 | 2019-01-24 18:00 | 12 h |
| KCS-USDT | 2017-10-18 18:00 | 2017-10-19 04:00 | 10 h |
| LTC-USDT | 2018-11-03 14:00 | 2018-11-03 22:00 | 8 h |

**Consequences for the simulator**

* A held coin with no bar at the current step simply carries forward; the mark-to-market uses its
  **last known close**, never a forward-filled guess.
* The RSI of a gappy coin is computed on **that coin's own bar sequence** — the gaps do not create
  synthetic flat bars. (A gap does not count as a zero-change period in Wilder's smoothing.)
* A coin that starts late contributes no signal before its first bar, and no index contribution
  before its first bar either.

---

## 9. Data-quality notes

These do not affect the evaluator (it only reads `close`) but they explain surprising numbers.

| Finding | Detail |
| --- | --- |
| **3 rows violate the OHLC bounds** | In all three the `high`/`low` columns are inconsistent with `open`/`close`; the `close` itself is fine. BTC data row 967 (`2017-11-29T07:00`): `high` 9700 < `close` 10551.000002. ETH data row 9602 (`2018-11-29T12:00`): `low` 118.041925 > `close` 118.000001. XRP data row 629 (`2019-01-10T13:00`): `high` 0.336896 < `close` 0.339777. |
| **2,140 bars have `volume == 0`** | and *exactly* those 2,140 bars also have `turnover == 0` (no row has only one of the two zero). ZEC accounts for 1,299 of them, LTC 231, XRP 268, BNB 122. Zero volume means "no trades in that hour"; the price is still valid. |
| **Exchange-wide outages create flat runs** | 2019-02-17 → 2019-02-18 has **18 identical consecutive closes** for BTC, ETH, KCS, LTC and XRP simultaneously (KuCoin outage). 2021-02-07 (5–7 h) and 2023-07-29 (3–4 h) hit almost every symbol. ZEC's longest run is 14 h (2019-12-27). |
| **Seed candles** | The first row of BTC (`4307`), ETH (`298`), KCS (`0.541221`) and LTC (`140`) has `open == high == low == close` with a near-zero volume (`0.001`) — the exchange's listing placeholder, not a real candle. |
| **Flat closes and RSI** | A 14-period window of identical closes yields `avg_loss == 0` → RSI `100`; the reference implementation must define this case explicitly (the Deno baseline returns `100`). |
| **Prices are never zero or negative** | minimum close over the whole dataset is `0.0740365` (KCS), maximum `126000` (BTC). |

---

## 10. Implementation notes (gotchas)

1. **Trailing newline.** Every file ends with `\n`, so splitting the file content on `"\n"`
   produces a final **empty string** that must be dropped (or the last row will be parsed as a
   bogus bar). Drop the header line too.
2. **Splitting on `","` alone leaves the `\n` glued to the last field** (`"126000\n"`). Either strip
   the newline from the line first or split on `","` *and* `"\n"`.
3. **Float parsing must accept both `40` and `34.385`** — see §4. A plain `parseFloat`/`atof` does;
   a strict "must contain a dot" parser does not.
4. **Do not assume a continuous series.** The union timeline has 28 holes (§7); a coin's own series
   can have hundreds of gaps (§8).
5. **Map timestamps to timeline steps, never arithmetic.** `step = (ts - t0) / 3600` is wrong
   because of the holes. Build the sorted union and look the timestamp up.
6. **RSI is per coin, over that coin's own bars.** Do not pad a coin's series with the global
   timeline.
7. **Process symbols in sorted order** so that the alphabetical tie-break of the buy rule is
   deterministic and independent of file-read order or task scheduling.
8. **The index is equal-weighted over 20 coins, each investing `10,000 / 20` at its own first bar.**
   A coin listed in 2026 contributes nothing before then; the index therefore starts below 10,000
   and grows as coins join.
9. **Only `timestamp` and `close` are needed** — skip the other six columns if the parser allows it
   (≈6× less string work).

---

## 11. Reference results on this dataset

Produced by the Deno baseline (`deno/`) — the yardstick every other implementation must match.
Only the `sim time` line may differ.

```
RSI(14) · 20 coins · 78,949 hourly steps · 2017-10-04 → 2026-10-20
equity / index       0.3611x  (equity 19,295 · index 53,432)
sharpe (hourly)       0.5811
win / loss            1.8592  (264 W / 142 L / 406 trades)
avg gain / trade    +0.7751%
avg holding time    144.43 h
```

| Metric | Value |
| --- | --- |
| Timeline steps | 78,949 |
| Final strategy equity | 19,295 USDT |
| Final market index equity | 53,432 USDT |
| Equity / index | 0.3611x |
| Sharpe (hourly, annualised ×√8760) | 0.5811 |
| Closed trades | 406 (264 wins / 142 losses / 0 zero-return) |
| Win / loss ratio | 1.8592 |
| Average gain per trade | +0.7751 % |
| Average holding time | 144.43 steps |

---

## Appendix — how this was measured

A throwaway Python script walked all 20 files once and produced:

* the header, encoding, line-ending and field-count checks (§2),
* the `datetime` ↔ `timestamp` consistency check over **all** rows (§3),
* the number-format census (§4),
* the sortedness and duplicate-timestamp check (§2),
* per-coin row counts, ranges, gap histograms, coverage, flat-close streaks, zero-volume counts
  and price extremes (§6, §8, §9),
* the union timeline, its 28 holes and the per-step coverage histogram (§7),
* the OHLC-bound violation scan (§9).

The script lives outside the repository (it is a one-off), but every number above is reproducible
from the CSVs with the checks described inline.
