---
name: MultiTF_Scalper
files: [MultiTF_Scalper/MultiTF_Scalper.mq5]
market: XAUUSD (implied)
timeframe: M5 gate, but the "M5" indicators are built on M15; bias from D1/H4/H1/M15
family: indicator
origin: own
verdict: no-edge (and doesn't match its own description)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# MultiTF_Scalper

A top-down bias score (D1 → M15), then an "M5 ribbon" pullback with oscillator confirmation. It advertises 3 partial take-profits; in the code there's only one TP at 2 R.

## Entry (as the code does it)
- Bias score (`MultiTF_Scalper.mq5:237-280`): D1 EMA200 vs bid = 3 points, H4 21/50 stack = 2, H1 21/50 + RSI 50 = 2, M15 21/50 = 1. The threshold is **≥ 6** (`:276`),
  though the comment says 5 (`:235`). In practice D1 must agree.
- **Timeframe mix:** the "M5" EMAs, RSI, Stochastic, MACD and ATR are created on **M15** (`:113-119`) but compared index-by-index with **M5** candles (`:296`, `:307`, `:312`).
  So an M5 low can be tested against an M15 EMA up to 45 minutes old.
- Oscillators: 2 of 3 must agree. The MACD rule reduces to "histogram > 0" (`:382`).
- Server hours 11 and 15–16, Tuesday skipped, max 3 trades a day, 6-bar cooldown.

## Exit
SL = 1.2 × ATR(M15), clamped to 150–800 points; one TP at 2 R (`:415`); BE + 10 points at 1 R (`:479-484`).
- **The 3 partial TPs aren't implemented:** the TP1/TP3/percentage inputs (`:49-53`) and `TradeInfo` (`:93-104`) are never used.
- **[verified] Trailing is dead code**, for the same reason as in [SMC_Confluence](smc-confluence.md). Before BE the BE branch wins (`:479` vs `:486`). After BE, `slDist ≤ 0`
  → `continue` (`:471`). So the real exits are SL, BE or 2 R.

## Sizing & risk
Fixed 0.10 lot.

## Backtest evidence
[from report] [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md): 1 year **-$456, PF 0.83, win rate 46.8%, max DD 9.6%, 62 trades**;
last month +$208, PF 3.59, **4 trades** (noise).

## Verdict & next step
Loses, and what it does isn't what it says. If you keep it: build the ribbon on M5, implement the partial TPs or delete those inputs, and fix the trailing.

## Related
[common code traps](../concepts/common-code-traps.md) · [SMC_Confluence](smc-confluence.md) (same dead-trail pattern)
