---
name: GoldenTimeStrategy (V5) + GoldenTime_1845
files: [GoldenTimeStrategy/GoldenTimeStrategy.mq5, GoldenTimeStrategy/GoldenTime_1845.mq5, GoldenTimeStrategy/README.txt]
market: XAUUSD
timeframe: M1 zone (V5 runs on the chart timeframe, tested on M5)
family: session-breakout
origin: own (18:45 IST "golden time" idea)
verdict: no-edge (README: net negative over 2 years)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# GoldenTime (18:45 zone breakout)

Marks a small zone at a fixed clock time ("18:45 IST") and trades the first candle that closes outside it. The planned exit was to take 80% at TP1 and trail the rest,
but the code never actually does that.

## Entry (as the code does it)
- **V5** (`GoldenTimeStrategy.mq5`, "v5.00"): the zone is 3 M1 bars at **13:15 server** (`:11-13`, `:167-174`). That's 18:45 IST only on a **UTC+0** server
  (README); on FundingPips' UTC+2 it's 16:45 IST. A closed bar beyond the zone triggers entry (`:308`, `:340`). The H1 ATR filter allows 10–80 pips = $1–$8
  (`:251-262`), which blocks most days at today's volatility. The "conflicting trend" return (`:235`) can never be reached.
- **1845** (`GoldenTime_1845.mq5`, "v3.00"): the zone is at **18:45 server** (`:13-14`), at least 50 points wide. Entry on an M1 close beyond the zone + 20 points that
  opened inside it, with body > 30% (`:195`, `:206`). After the first trade, the day is locked to that direction.

## Exit
- **[verified] The partial-profit design never runs.** The broker TP is placed exactly at TP1 (`GoldenTimeStrategy.mq5:327`, `:358`: `tp = entry ± TP1Pips`),
  and the partial-close trigger is the same price (`:396-397`). The broker TP fires first and closes everything, so the 80% partial, the BE move, the runner and the trail are
  dead code. The same applies to 1845 (`:232` vs `:324`) [unverified].
- SL = the opposite side of the zone, capped at 30 pips / 500 points. 1845 closes everything at 23:00; V5 has no EOD close.

## Sizing & risk
V5: fixed 0.10 lot. 1845: 1% via tick value, and **lot = 0 if tick value is 0** (`GoldenTime_1845.mq5:285`). It re-enters up to 3 times after *any* close,
wins included (`:98-113`). **Both files use magic 184500**, so they'll manage each other's trades if run together.

## Backtest evidence
- [from report] [`README.txt`](../../GoldenTimeStrategy/README.txt): V5, 1 month XAUUSD M5: +$305.20, win rate 53%, PF 1.28, max DD 4.26%.
  **Over 2 years: net negative.**
- [from report] [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md), 1 year: **-$36, 2 trades**.

## Verdict & next step
No edge, and the exit logic doesn't do what it was designed to do. Park it. If you revive it: put the TP at the runner target and do the partial close in code;
give the two files different magics; and fix the hour for the broker's offset.

## Related
[server time](../concepts/server-time.md) · [position sizing](../concepts/position-sizing.md) · [RangeEngulf](range-engulf.md)
