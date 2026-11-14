---
name: DoubleTrapStrategy
files: [DoubleTrapStrategy/DoubleTrapStrategy.mq5, DoubleTrap_V1.set]
market: XAUUSD
timeframe: M15 logic (any chart timeframe)
family: pattern
origin: own
verdict: untested (no backtest on record)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# DoubleTrapStrategy

Finds a double top or bottom at a support/resistance zone, then waits for a "trap": a wick through the pattern that closes back inside. It trades the reversal.

## Entry (as the code does it)
- M15 logic, but it runs once per *chart* bar (`DoubleTrapStrategy.mq5:143`). On a chart below M15 the same setup is checked several times.
- Sessions 10–13 and 15–21 server with `<=`, so they really end at 13:59 and 21:59 (`:679-680`). Tuesdays are skipped.
- S/R zones: clusters of ≥ 3 swing points within ±300 points (`:213-277`). "Resistance" just means the zone is above price (`:275`).
- Double top/bottom: two swings within 200 points, 5–30 bars apart. The swing test can read the forming bar 0 (`:307`).
- **Double tops are always checked first, and the function returns** (`:350`). Bottoms are ignored whenever any top exists in the 40-bar window, so the EA leans toward sells.
- Trap: bar 1 or 2 wicks 30–500 points past the pattern and closes back inside (`:460-477`).

## Exit
SL = trap wick + 0.45 × ATR; TP = 2.5 R from the bar-1 close (`:479-481`). BE +20 points at 1 R, trailing from 2 R. No EOD close.
The neckline-TP code does nothing: `MathMin(neckline, tp)` with neckline > tp just returns tp (`:484-485`, `:528-529`).

## Sizing & risk
Fixed 0.10 lot (`:560`); up to 3 trades a day, one at a time. `DoubleTrap_V1.set` (repo root) matches the code defaults.

## Backtest evidence
**No backtest on record.**

## Issues found in code
- [unverified] The cooldown reads the last deal in the **whole account** (`:657-660`), and calls `HistorySelect` on every tick.
- [unverified] The SL-distance filter uses the bar-1 close, not the actual fill price (`:183-184`).

## Verdict & next step
Over-filtered, with a sell bias. Check tops and bottoms independently and fix the neckline target before running a first backtest.

## Related
[SMC terms as coded](../concepts/smc-terms-as-coded.md) · [LiquiditySweepScalper](liquidity-sweep-scalper.md) (also trades wick traps)
