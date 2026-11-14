---
name: SMC_LumenTrades
files: [SMC_LumenTrades/SMC_LumenTrades.mq5, SMC_LumenTrades/SMC_v3_rr15.set, SMC_LumenTrades/SMC_v3_noBE.set]
market: XAUUSD
timeframe: H1 structure, M5 entry
family: smc
origin: youtube (Lumen Trades method)
verdict: broken (0 trades in the FundingPips tester; swing tracking bug)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# SMC_LumenTrades (v3.00)

An attempt at the Lumen Trades SMC method. It waits for an H1 change of character (ChoCH), marks the H1 order block, then enters on an
M5 candle that rejects from that block. This is the **only** EA here that is built entirely around % risk sizing. That is also why it
never traded in the FundingPips tester.

## Entry (as the code does it)
- H1 swings: strict 5-bar fractals, tested only at bar 6 (`SMC_LumenTrades.mq5:151-162`).
- "ChoCH" (bullish): the last swing low is lower than the previous one, **and** the H1 bar-1 close is above the last swing high (`:177`). It doesn't check that the
  break is *new*, so the same setup can re-arm after a trade closes (`:113`).
- Order block: the most recent opposite-colour H1 candle in bars 1–30, using the full wick range (`:192-203`).
- Trigger: an M5 bar 1 that touches the OB, closes past the OB midpoint, and shows either a wick rejection or ≥3 touches (`:279-299`).
- Hours 7–20 server time (`:124`).

## Exit
- SL = OB low − 20 points, capped at 600 points. Trades with SL < 80 points are skipped (`:332-336`).
- TP = `MathMax(tpRR, g_dolTarget)` (`:342`): the "draw on liquidity" target can only *widen* the TP.
- Break-even +10 points at 1 R (`:409-412`).

## Sizing & risk
1% of balance, sized from tick value and tick size (`:456-473`). It rounds up to the minimum lot, which can exceed 1% on tight balances.
Max 2 trades/day.

## Settings files
`SMC_v3_rr15.set` (RR 1.5, no BE) and `SMC_v3_noBE.set` (RR 2, no BE). Both are UTF-16 files with inputs in alphabetical
order. [unverified] If MT5 needs declaration order (see [backtesting method](../concepts/backtesting-method.md)), some
overrides may be ignored.

## Backtest evidence
[from report] [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md): **0 trades on all settings**, blamed on the
tick-value bug. **No working backtest on record.**

## Issues found in code
- **[verified] Zero lot when tick value is 0:** `if(tickVal <= 0 || tickSize <= 0) return 0;` (`:463`). The report's suggested fix
  "use `UseFixedLot=true`" **cannot work here**, because this EA has no such input. See [position sizing](../concepts/position-sizing.md).
- [unverified] **Swings are lost:** `OnTick` returns early while in a trade, at the daily cap, or outside hours (`:120-124`), all *before*
  `UpdateH1Swings` (`:131`). That function only tests one bar index, so swings that form overnight or during a trade are never recorded.
- [unverified] `g_obHigh` is never reset, so the `if(g_obHigh == 0) return;` guard (`:204`) only works once.
- [unverified] The in-trade state lives in the variable `g_inTrade` (`:108`), which is lost on a restart. SL and TP are not normalized (`:332`, `:339`). The BE flag is set
  without checking that the modify succeeded (`:412`).

## Verdict & next step
Not testable as it stands. To revive it: add a tick-value fallback (or a fixed-lot input), call `UpdateH1Swings` before the early
returns, and require the ChoCH break to be new.

## Related
[position sizing](../concepts/position-sizing.md) · [SMC terms as coded](../concepts/smc-terms-as-coded.md) ·
[GoldLondonStrategy](gold-london.md) (also from Lumen Trades)
