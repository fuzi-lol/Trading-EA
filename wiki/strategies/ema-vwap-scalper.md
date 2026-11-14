---
name: EMA_VWAP_Scalper
files: [EMA_VWAP_Scalper/EMA_VWAP_Scalper.mq5, EMA_VWAP_Scalper/EVS_tuned.set, EMA_VWAP_Scalper/EVS_risk05.set, EMA_VWAP_Scalper/EVS_risk1.set, EMA_VWAP_Scalper/EVS_fixed01.set]
market: XAUUSD (symbol not stated)
timeframe: M1 (M5 trend filter)
family: scalper
origin: own
verdict: no-edge (loses even with tuned params; 50.8% drawdown)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# EMA_VWAP_Scalper

A textbook EMA-crossover trend scalper with volatility filters, and a VWAP filter that isn't computed correctly.

## Entry (as the code does it)
An M1 EMA 9/21 cross between bars 2 and 1 (`EMA_VWAP_Scalper.mq5:224-227`, `:255-256`). Also needs: price on the trend side of the M5 EMA50 and of the VWAP,
ADX ≥ 20, ATR ≥ its 50-bar average, Bollinger width ≥ 0.15%, and RSI not beyond 25/75 (`:232-285`). Hours 9–19 server time.

## Exit
SL = ATR × 1.5; TP = 2 R; trailing 100 points from 1 R (`:289-390`).

## Sizing & risk
0.5% of balance; tick value 0 → lot 0 → no trade (`:408`). No daily-loss guard.

## Settings files
`EVS_tuned`, `EVS_risk05` and `EVS_risk1` tighten the filters (ADX 25, ATR ratio 1.2, BB 0.2%, RSI 30/70, SL 2 × ATR, trail 80, cooldown 10).
`EVS_tuned` uses a fixed 0.1 lot; the `risk` sets use 0.5% and 1%. `EVS_fixed01` = defaults with a fixed 0.1 lot.

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]: `EVS_risk05`, 1 year: **-$205, PF 0.99, max DD 50.8%,
131 trades**. Defaults gave 0 trades in the FundingPips tester (the tick-value bug).

## Issues found in code
- [unverified] **The VWAP is wrong:** `CalcVWAP` only runs after the in-trade, session and cooldown checks (`:141-169`). Bars during trades and cooldowns are
  skipped, so it isn't a real session VWAP. See [common code traps](../concepts/common-code-traps.md).
- [unverified] `atrValues[50]` is a fixed-size array (`:236`). Setting `ATR_MA_Period` > 50 makes the copy fail, and the EA never trades.
- `VWAPAsEntry` (`:31`) is never used.

## Verdict & next step
Drop it, or fix the VWAP first (compute it from M1 bars since the session start, every bar) and retest. As it stands it loses.

## Related
[position sizing](../concepts/position-sizing.md) · [M1_MomentumScalper](m1-momentum-scalper.md) (same VWAP bug)
