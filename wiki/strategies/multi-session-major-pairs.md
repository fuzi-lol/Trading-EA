---
name: MultiSession_MajorPairs_EA
files: [MultiSession_MajorPairs_EA/MultiSession_MajorPairs_EA.mq5]
market: forex majors (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, NZDUSD) — one chart per pair
timeframe: chart timeframe (H1 trend filter)
family: session-breakout + mean-reversion
origin: third-party (L0rdTrey Systems)
verdict: unproven — the report's headline numbers don't add up
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# MultiSession_MajorPairs_EA

**Not our code.** It is byte-identical to `M1_MomentumScalper/L0rdtrey EAs/EAs by TREY/MY EAs/MultiSession_MajorPairs_EA.mq5`, with
`#property copyright "L0rdTrey Systems"`. See [third-party](../third-party-l0rdtrey.md). The Oct report ranks it #1. Read the
"Backtest evidence" section before you believe that.

It runs two strategies on one chart: an **Asian-range breakout** in the morning and **Bollinger + RSI mean reversion** in the afternoon.

## Entry (as the code does it)
- Asian range = server hours 00–07 (`MultiSession_MajorPairs_EA.mq5:32-33`). On a UTC+2 server that's 22:00–05:00 UTC, so the "London
  breakout" at 07:00 server fires about 3 hours **before** London opens. The range is built from bar 1 while the hour is below 7, so the last Asian bar is left out
  (`:202-209`). The range must be 15–80 pips (`:212-217`).
- Breakout, 07–12: price is 30 points past the range, bar 1 closed past it, and the H1 EMA50 agrees (`:250-260`). It can re-enter after a trailed exit.
- Mean reversion, 13–21: bar-1 close outside BB(20,2) and RSI < 30 / > 70 (`:335`, `:357`). The "previous candle also outside" rule in the comments isn't
  coded (`close2` at `:325` is never used).

## Exit
- Breakout: SL at the far side of the range, TP 2 R. Mean reversion: SL 300 points, TP at the middle band or 1.5 R (`:262-264`, `:340-344`).
- **[verified] Trailing starts at 150 points of profit and trails 50 points behind** (`InpTrailingStart = 150`, `InpTrailingStep = 50`, `:54-55`,
  `:458-478`). On 5-digit pairs that's 15 pips / 5 pips, so most winners end up as small trailed wins. That's why the win rate is high and the PF is near 1.
- Everything closes at 23:00 server (`:152`).

## Sizing & risk
`InpRiskPercent = 1.0` of **balance** via tick value (`:22`, `:386-394`), so it compounds. Sizes that are too small are raised to the minimum lot (`:410`). The breakout and the
mean-reversion trade can be open together, so up to 2% risk per pair. `PipSize` handles JPY correctly (`:419-423`).

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]: 1 year, six separate single-pair runs:
EURUSD +$12,086 (PF 1.14), NZDUSD +$9,797 (PF 1.17), GBPUSD +$4,258 (PF 1.03), USDJPY +$196 (PF 1.26), USDCAD -$2,863 (PF 0.97),
AUDUSD -$5,060 (PF 0.93). Sum +$18,414, 2,103 trades. Last month: +$15,981 summed.

**Why these numbers can't be taken at face value** (arithmetic on the report's own figures):
- The report header says a $10,000 deposit, but **average loss = net ÷ (PF − 1) ÷ number of losers**. For EURUSD in the last month: 5,038 ÷ 1.63 ÷ 5 ≈ **$618 per loss**,
  while max DD is 1.70% (= $170 on $10k). One loss can't be bigger than the whole drawdown. All rows fit a **~$100k deposit at 1% risk**
  [inference]. In that case the year is about **+3% per pair-account**, not +184%.
- **USDJPY looks like a sizing artifact:** an average loss of about $6–8 suggests the tester returned the JPY tick value unconverted (risking ¥1,000, not $1,000)
  [inference]. The "0.02% DD" is not a sign of safety.
- The last month (+$15,981) is 87% of the whole year (+$18,414). On the pairs that carry the total, PF is only 1.03–1.17.
- "+$18,414 across 6 pairs" sums six separate accounts. It isn't one portfolio's equity curve.

## Issues found in code
- **[verified] The daily-cap and spread checks return before the end-of-day close and before trailing** (`:143`, `:147` come before `:152`, `:159`). After 6 trades in a day,
  or whenever spread > 25 points, open positions get no trailing and **no 23:00 close**, so they can stay open overnight.
- [unverified] `PositionModify` and `PositionClose` results aren't checked (`:476`, `:510`). Strategies are told apart by comment text, not by magic number.

## Verdict & next step
Possibly a thin edge on EURUSD/NZDUSD, but the evidence is badly labelled. Rerun with a **stated $10k deposit, a fixed lot, and every tick**, on 2+
years per pair. Move the cap and spread checks below the EOD close and trailing first.

## Related
[server time](../concepts/server-time.md) · [position sizing](../concepts/position-sizing.md) ·
[backtesting method](../concepts/backtesting-method.md) · [third-party](../third-party-l0rdtrey.md) ·
[YT_Strategies London Breakout](yt-strategies.md) (the same Asian-range idea, tested on 2 years)
