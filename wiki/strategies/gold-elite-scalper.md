---
name: GoldEliteScalper
files: [GoldEliteScalper/GoldEliteScalper.mq5, GoldEliteScalper/PropFirm_10K.set, GoldEliteScalper/PropFirm_50K.set]
market: XAUUSD
timeframe: M1 execution, M5 decisions (M15 filter)
family: scalper
origin: own
verdict: marginal (very safe drawdown, almost no profit)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# GoldEliteScalper (1,446 lines, the biggest own EA)

An "ICT checklist" scalper for a $10K prop account. Several signals (EMA cross, VWAP, tick-volume CVD, liquidity sweep, FVG or order block,
candle pattern) vote for a direction and add up a confluence score. It trades only in London and NY hours and has strong account guards.

## Entry (as the code does it)
- Runs on each new M1 bar but evaluates entries once per M5 bar (`GoldEliteScalper.mq5:327-329`, `:385-387`).
- Filters (server time): London 10–13, NY 15–20 (`:33-36`, `:455-461`). It skips Tuesday (`:372`) and hours 11, 16 and 17 (`:377-378`). Spread must be < 40 points, and there's a cooldown.
- Votes: EMA 9/21 cross on M1 bars 1–5, with M5 EMA21 and M15 EMA50 alignment (`:978-1006`). Also session VWAP band (`:1016-1038`), CVD from tick volume
  (`:493-544`), M1 sweep of M5 swing levels (`:628-671`), price in an FVG or OB (`:1068-1119`), and an engulfing, pin bar or star on bar 1 (`:883-945`).
- Direction needs ≥3 votes one way (`:1139-1144`). Then the score must reach `MinConfluence` = 4 (5 for sells) (`:1148-1150`). The header
  claims "6 of 6" (`:11`).

## Exit
SL = ATR × 1.2, clamped to 100–500 points, or just past the sweep wick. TP = 2 R, but the "next S/R" option can replace it with any level beyond 1.5 R,
which may make it *closer* (`:1184-1185`). BE +15 points at 1 R; trail 80 points from 1.5 R; force-close at 20:00 (`:1378-1418`).

## Sizing & risk
0.5% of balance, shrunk to fit the remaining daily budget (`:1287-1297`). If tick value is 0 → no trade (`:1304`). A margin cap that assumes no leverage, plus
a 0.05 lot per $10K cap (`:1320-1334`), usually wins, so real size is about 0.01–0.03 lot (well under 0.5% risk). Daily loss guard 2.5%;
total guard 10% from peak (`:396-436`).

## Settings files
`PropFirm_10K.set` is the same as the defaults. `PropFirm_50K.set` narrows London to 12–13 and skips Tue/Thu/Fri and hours 16–17. It also widens the SL
(1.5 ATR, 150–600 points) and uses 0.75% risk with a 20-minute cooldown.

## Backtest evidence
[`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) [from report]: 1 year **+$75, PF 1.12, win rate 46.5%, max DD 0.7%,
447 trades**; last month +$16, PF 1.43. The tiny drawdown and the tiny profit both come from the lot caps above.

## Issues found in code
- **[verified] The confluence score is inflated.** The VWAP block adds a point whenever the buy and sell counts differ, even if VWAP voted for neither
  (`:1036-1037`). Any active sweep adds a point, even one in the wrong direction (`:1064`). RSI 40–60 adds a 7th point (`:1135`).
- [unverified] After a guard trips, the close is tried once (`:403-407`), and the early `return` (`:319-320`) then skips `ManagePositions`. A
  position that failed to close is left unmanaged.
- [unverified] Peak and day-start balance reset on every re-init (`:253-254`). After a restart the BE code can move an already-trailed SL
  backwards (`:1366-1386`).
- [unverified] `g_prevFastEMA` only updates inside `EvaluateEntry` (`:1012`), so the "previous" value can be hours old.

## Verdict & next step
The safest drawdown here, but the edge is near zero and the score doesn't mean what it says. Fix the scoring so each signal earns its own
point, then check whether a real 4-of-6 confluence beats the current loose version.

## Related
[position sizing](../concepts/position-sizing.md) · [common code traps](../concepts/common-code-traps.md) ·
[PropFirmScalper](prop-firm-scalper.md) · [SMC_Confluence](smc-confluence.md)
