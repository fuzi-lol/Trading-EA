---
name: GoldAggressiveCompounder
files: [GoldAggressiveCompounder/GoldAggressiveCompounder.mq5]
market: XAUUSD
timeframe: M5 (M15, H1 filters)
family: scalper
origin: own
verdict: untested — high risk by design
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# GoldAggressiveCompounder

**Danger: high risk.** It risks 3% of equity per trade, runs up to 5 positions at once and up to 15 trades a day, and adds to winners.
It has **no daily-loss or drawdown guard**.

## Entry (as the code does it)
Runs once per new M5 bar, in sessions 7–12 and 13–21 server time, and skips Tuesday. Four independent signals, each with its own magic number and at most
one open position per signal:
1. EMA 9/21 cross with ADX ≥ 20 and price on the right side of the M15 EMA50.
2. RSI(14) bounce back out of 30/70.
3. Bollinger Band rejection + Stochastic.
4. Two strong candles in a row.

The H1 EMA200 filter is computed (`:220-221`) but never used.

## Exit
SL = ATR × 1.5, clamped to 100–800 points; TP = 2 R; BE +10 points at 1 R (`:374-378`); trailing from "1.5 R".

## Sizing & risk
- `RiskPercent = 3.0`, `MaxPositions = 5`, `AllowPyramid = true`, `MaxPyramidAdds = 2` (`GoldAggressiveCompounder.mq5:22-25`). [verified]
- Pyramids add half size at 1 R. This adds to **winners**, so it is not martingale.
- If tick value is 0 it falls back to "$1 per point per lot" (`:475-481`). That's right for 2-digit gold and 10× too big on 3-digit.

## Backtest evidence
**No backtest on record.**

## Issues found in code
- **[verified] The EMA cross is one bar late.** `CopyBuffer(h_fastEMA, 0, 1, 3, fast)` into a non-series array (`:185`) makes `fast[0]` bar 3 and
  `fast[2]` bar 1. The test `fast[0] <= slow[0] && fast[1] > slow[1]` (`:232`) finds a cross between bars 3 and 2 and never looks at bar 1.
- [unverified] R is recalculated from the *current* SL every tick (`:361`). After BE, R ≈ 10 points, so the "1.5 R" trail fires almost at once.
- [unverified] The pyramid tracker stores a **deal** ticket (`trade.ResultDeal()`, `:334`) and compares it with a **position** ticket (`:424`).
  On a live server those differ, so pyramiding probably never fires live.
- [unverified] Fill mode is hard-coded to IOC (`:107`).

## Verdict & next step
Don't run it on a prop account. If you want to keep it as an experiment: add a daily-loss stop, fix the bar indexing (`ArraySetAsSeries`), measure R from the
*original* SL, then backtest at 1% risk first.

## Related
[position sizing](../concepts/position-sizing.md) · [common code traps](../concepts/common-code-traps.md) ·
[M1_MomentumScalper](m1-momentum-scalper.md) (similar four-signal design)
