---
name: GoldLondonStrategy (V1, V3)
files: [GoldLondonStrategy/GoldLondonStrategy.mq5, GoldLondonStrategy/GoldLondonV3.mq5, GoldLondonStrategy/README.txt]
market: XAUUSD
timeframe: H1 range, M5 entry
family: smc + session-breakout
origin: youtube (Lumen Trades, 1:5 RR idea)
verdict: broken (stale pip filters → almost never trades)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# GoldLondonStrategy (V1 = "v2.00" in the file header, and V3)

Marks the London-open H1 candle. Waits for a liquidity grab (a wick out of the range and a close back in), then enters on an M5 FVG retest, targeting the other
side of the range.

## Entry (as the code does it)
- Range: the 10:00 server H1 candle, read from 11:00 (`GoldLondonStrategy.mq5:151-167`). On a NY-close server that's London 08:00 all year.
- Grab: the last closed M5 bar wicks ≥ 2 pips beyond the range and closes back inside (`:209`, `:216`, `:230`).
- Trend veto: H1 EMA50 and Daily EMA20 must not both be against the trade (`:196-197`, `:222`, `:234`).
- FVG: a standard 3-bar gap in the last 30 M5 bars (`:247-263`). It **doesn't have to form after the grab**: 30 bars reaches back 2.5 hours.
- Entry when price is inside the FVG and there's ≥ 2 R to the far end of the range (`:320`, `:348`).

## Exit
SL beyond the FVG + 3 pips; TP = the other side of the range (`:323-324`). The 16:00 cutoff only stops new entries. No BE, no trailing, no EOD close.

## Sizing & risk
Fixed 0.10 lot (`:15`).

## V3 vs V1
V3 hard-codes the range filter to 8–60 pips (V1: 10–80) and the max FVG to 25, and drops the direction mode. Its new "score" filter (`GoldLondonV3.mq5:138-143`) can
only be +2/0/−2, so it **behaves exactly like V1's filter**. The README's claim that V3 added a trend filter is wrong [unverified].

## Backtest evidence
- [from report] [`README.txt`](../../GoldLondonStrategy/README.txt), V3, 2 years XAUUSD M5: **+$56.50, win rate 33.3%, PF 1.38, max DD 0.66%,
  21 trades**.
- [from report] [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md), 1 year: **-$51, 5 trades**.

## Issues found in code
- [unverified] **The pip filters are stale for today's gold price.** Range $1–$8 (V1) or $0.80–$6 (V3) at a $0.10 pip. With gold at $3–4k, most London H1
  candles are bigger than that, so nearly every day is skipped. That explains 5 trades a year.

## Verdict & next step
The idea is coherent, but the filters were sized for older, cheaper gold. Scale the range and FVG limits by ATR (or by % of price) and require the FVG to form
after the grab. Then retest.

## Related
[SMC terms as coded](../concepts/smc-terms-as-coded.md) · [common code traps](../concepts/common-code-traps.md) ·
[SMC_LumenTrades](smc-lumentrades.md) · [AsianRangeOB](asian-range-ob.md)
