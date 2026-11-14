---
name: LiquiditySweepScalper
files: [LiquiditySweepScalper/LiquiditySweepScalper.mq5, LiquiditySweepScalper/LSS_propfirm.set, LiquiditySweepScalper/LSS_fixed01.set, LiquiditySweepScalper/LSS_fixed02.set, LiquiditySweepScalper/LSS_tight.set, LiquiditySweepScalper/LSS_safe.set, LiquiditySweepScalper/LSS_025.set]
market: XAUUSD (symbol not stated in code)
timeframe: M1 entries, M15 levels
family: scalper
origin: own
verdict: marginal (break-even on defaults; one good month on LSS_propfirm)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# LiquiditySweepScalper

A single-candle stop-hunt reversal. It marks M15 swing highs and lows as support and resistance. When an M1 candle wicks past a level and closes back
inside, it trades the reversal.

## Entry (as the code does it)
- Levels: M15 swings (5 bars each side, at least 3 bars old) over 200 bars, merged within 200 points (`LiquiditySweepScalper.mq5:196-262`).
- Sweep: the M1 bar-1 wick is 20–300 points beyond a level, with the close back inside (`:283-344`).
- Confirmation (engulfing, pin bar, strong candle) runs on the **same bar** right after the sweep is found (`:185-189`). The sweep candle can confirm itself,
  despite the "enter on next candle" comment (`:9`).
- Sessions 8–12 and 14–20 server time. No spread filter.

## Exit
SL = 20 points beyond the wick. If that's wider than the max, it's pulled in to 400 points, which puts the stop *inside* the sweep (`:431`, `:476`).
TP is at least 1.5 R, or a further S/R level. Trailing 150 points from 1 R; no BE.

## Sizing & risk
1% of balance. If tick value is 0 it silently uses `FixedLot` 0.10 (`:614-619`); this fallback was added after the Oct report. The equity guard is
**off** by default (`:49`). When on, it only blocks new trades and never closes positions.

## Settings files
All the sets use London 9–12, NY 15–19, a minimum 50-point sweep, a max 250-point SL, MinRR 2 and 2 trades/day. `LSS_fixed01` and `LSS_fixed02` trade 0.1 and 0.2 lots.
`LSS_propfirm` turns the guard on but uses a fixed 0.2 lot, so its `RiskPercent=0.5` is ignored.

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]:
- Defaults, 1 year: **+$382, PF 1.02, win rate 46.6%, max DD 8.8%, 1,242 trades** (break-even).
- Defaults, last month: -$12, PF 0.99, 102 trades.
- `LSS_propfirm`, 1 month only: +$612, PF 1.63, max DD 2.0%, 54 trades. One month isn't evidence; the 1-year run with this set is missing.

## Issues found in code
- [unverified] `g_inTrade` lives only in memory (`:75`, `:150`). After a restart, the open trade isn't trailed and a second one can open.
- [unverified] The guard baselines reset on init (`:105-106`).

## Verdict & next step
Defaults have no edge across 1,242 trades. The one thing worth doing: run `LSS_propfirm` for 1–2 full years.

## Related
[position sizing](../concepts/position-sizing.md) · [common code traps](../concepts/common-code-traps.md) ·
[SMC_LiqSweep_OB_IFVG](smc-bos-template-family.md) (sweep idea, SMC flavour)
