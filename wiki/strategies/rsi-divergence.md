---
name: RSI_Divergence (V1, V2)
files: [RSI_Divergence/RSI_Divergence.mq5, RSI_Divergence/RSI_Divergence_V2.mq5, RSI_Divergence/RSI_Divergence_V1.set, RSI_Divergence/RSI_Divergence_V2.set]
market: XAUUSD
timeframe: M5 (H1 trend filter)
family: indicator
origin: own
verdict: untested (no backtest on record)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# RSI_Divergence

Looks for an RSI divergence between the last two price pivots (in an RSI zone), then waits for an engulfing candle in the H1 trend direction. It enters with a **stop order**
at the engulfing extreme and takes profit in stages, based on RSI levels.

## Entry (as the code does it)
- Pivots: strict 5-bars-each-side swings, searched from bar 6 to 50 (`RSI_Divergence.mq5:236-309`, `:394`, `:440`). Everything is closed, so there's **no repainting**, but each pivot
  is confirmed 5 bars late. RSI is read at the price-pivot bar. Only *adjacent* pivots are compared, and they must be ≥ 5 bars apart.
- Zone: a bearish divergence counts if recent RSI ≥ 60 (hard-coded) or older RSI ≥ 70; bullish uses 40/30 (`:419`, `:464`).
- Trigger: an engulfing bar 1 + a divergence anywhere in the window + the closed H1 EMA50 trend (`:532-571`).
- Order: a stop order at the engulfing bar's low or high, expiring after 5 bars. SL = the 20-bar swing extreme ± 50 points, which must be 200–1500 points.

## Exit
- **V1:** no fixed TP. TP1 when RSI[1] ≥ 50 (a level, not a cross): close 50% and move to BE + 10 points (`:634-650`). This can fire while the trade is losing, which makes the BE
  stop invalid. TP2 at RSI ≥ 70 closes the rest. After that, it trails behind swings.
- **V2:** TP1 is price-based at 1 R and checked every tick (`RSI_Divergence_V2.mq5:741-787`): close half, BE + 10 points, hard TP at 3 R. Orders are sent **without a TP**
  until TP1 (`:606`, `:641`).

## Sizing & risk
Fixed 0.10 lot, so dollar risk varies about 7× between the smallest and largest allowed SL.

## V2 vs V1
V2 adds a freshness limit `InpMaxDivAge` (`:438`, `:487`), an optional strict zone, SL as % of price (`:561-567`), an H1 ADX limit and a skip-Tuesday option.
`InpRSITP1Level` is now unused. `RSI_Divergence_V2.set` sets MinSLPct 0.25 with MaxSLPoints 1500. On 2-digit gold at about $4,000 that means an SL of $10–$15. On a 3-digit
quote that band is impossible, so the EA **would never trade**.

## Backtest evidence
**No backtest on record** (no RESULTS file, and it isn't in the Oct report).

## Issues found in code
- [unverified] **V1 has no freshness check:** the same old divergence can trigger new entries on later engulfing bars.
- [unverified] The spread check (`:134`) runs *before* `ManagePositions` (`:142`), so a wide spread skips exit management for that bar.
- [unverified] The SL/trail helper `FindSwingHigh(1,…)` can read the forming bar 0 (`:175`, `:182`, `:483`).
- [unverified] **V1 and V2 share magic 20261025**, so running both makes each manage the other's trades.

## Verdict & next step
V2 is the one to test. Give it % risk sizing and its own magic, check the SL band against the broker's digits, then run a first 2-year every-tick backtest.

## Related
[common code traps](../concepts/common-code-traps.md) · [position sizing](../concepts/position-sizing.md) ·
[YT_GoldScalpers S1](yt-gold-scalpers.md) (another RSI-based gold entry)
