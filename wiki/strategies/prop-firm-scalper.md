---
name: PropFirmScalper
files: [PropFirmScalper/PropFirmScalper.mq5, PropFirmScalper/PF_phase1.set, PropFirmScalper/PF_aggressive.set, PropFirmScalper/PF_fixedTP.set, PropFirmScalper/PF_fixed02.set]
market: XAUUSD
timeframe: M1 (M5 filter)
family: scalper
origin: own
verdict: no-edge (break-even over 423 trades)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# PropFirmScalper

A fair value gap (FVG) pullback in the trend direction, in two short "kill zone" windows, built for prop-firm challenge rules.

## Entry (as the code does it)
- Kill zones 10–11 and 15–16 server time, at most 2 trades/day, 30-minute cooldown (`PropFirmScalper.mq5:27-35`, `:228-234`).
- M1 FVG on bars 1–3, at least 0.3 ATR wide (`:239-278`). A gap expires after 30 minutes (`:322`).
- Entry when a later bar-1 close lands back inside the gap, on the "right" half, with price on the trend side of the M5 EMA50 and RSI(14) within limits
  (`:307-367`). The EMA is read from the forming bar 0 (`:314`).
- The gap is marked as used *before* the filters run (`:334`, `:354`), so a touch the filters reject still uses it up.

## Exit
SL = the larger of (gap edge + 20 points) and (ATR × 1.5); TP = 2 R; trailing 80 points from 1 R (`:373-471`).

## Sizing & risk
Fixed 0.10 lot by default. In risk mode, tick value 0 → lot 0 → no trade (`:489`). Guards: 3% daily equity loss, 10% from the start balance,
and a 10% profit target. Each closes positions once, without checking the result (`:157-189`).

## Settings files
`PF_phase1`: 1% risk sizing + the NY PM zone. `PF_aggressive` and `PF_fixedTP`: fixed 0.2 lot, wider hours (9–12, 14–17, 19–20), 4 trades a day
(`PF_fixedTP` also turns trailing off). `PF_fixed02`: fixed 0.2 lot.

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]: 1 year **+$60, PF 1.01, win rate 46.8%, max DD 10.5%,
423 trades**; last month -$92, PF 0.88. The report puts it in "do not deploy".

## Issues found in code
- [unverified] `potentialLoss` (`:381-382`) is computed but never used, so the "pre-trade daily loss check" does nothing.
- [unverified] `ProfitTargetPct = 0` stops trading at once, because there's no `> 0` check (`:182`).
- [unverified] Trade state is lost on restart, as in [LiquiditySweepScalper](liquidity-sweep-scalper.md).

## Verdict & next step
No edge. Keep it only as a reference for prop-firm guard code, and fix those guards first.

## Related
[common code traps](../concepts/common-code-traps.md) · [GoldEliteScalper](gold-elite-scalper.md) (better guards)
