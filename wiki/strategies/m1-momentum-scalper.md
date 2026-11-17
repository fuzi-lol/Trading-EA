---
name: M1_MomentumScalper
files: [M1_MomentumScalper/M1_MomentumScalper.mq5, M1_MomentumScalper/optimize_v8.set]
market: XAUUSD
timeframe: M1 (M5, M15 filters)
family: scalper
origin: own
verdict: untested (v10; filters look hand-fitted)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# M1_MomentumScalper (v10.00)

A **buy-only** gold momentum scalper. Its session hours, skipped hour and skipped weekday look like they were fitted to past results one at a time.
Note: the folder also holds the 77 MB third-party `L0rdtrey EAs/` dump, which is **unrelated** to this EA
(see [third-party](../third-party-l0rdtrey.md)).

## Entry (as the code does it)
- Buys only (`M1_MomentumScalper.mq5:51-52`), above the M5 EMA50 and the VWAP (`:249`, `:272`).
- Filters: ADX(10) ≥ 15, tick volume ≥ its 20-bar average, ATR rising, Bollinger width ≥ 0.08% (`:235-240`).
- The first match wins: EMA 5/13 cross + Stochastic; RSI(7) bounce + strong candle; lower-band rejection + Stoch < 30; two bullish candles (`:275-318`).
- Sessions 8–10 and 14–19, skipping hour 15 and Wednesday, server time (`:55-66`, `:189-192`).
- **The header doesn't match the code:** it says session 2 starts at 16, Thursday is skipped, and there's an M15 EMA200 filter (`:6-8`). The code starts at 14,
  doesn't skip Thursday, uses EMA50, and computes the M15 trend but never uses it (`:244`, `:249`).

## Exit
SL = ATR × 1.5, clamped to 40–200 points; TP = 2 R; BE +5 points at 1 R; trail 40 points from 1.5 R (`:262-264`, `:391-449`).

## Sizing & risk
Fixed 0.10 lot. The 1% daily-loss cap uses balance only and ignores open losses (`:475-480`).

## Settings files
`optimize_v8.set` is an **optimizer range file for an older version**. It names inputs that no longer exist (`StartHour`, `EndHour`, `SkipHour11`,
`SkipHour12`), so it doesn't fit v10.

## Backtest evidence
**No backtest on record** (no v10 result anywhere in the repo).

## Issues found in code
- [unverified] VWAP is only updated after all filters pass (`:170-197`), the same bug as [EMA_VWAP_Scalper](ema-vwap-scalper.md).
- [unverified] The ATR and volume filters let trades through when data is missing (`:340`, `:486`). Fill mode is hard-coded IOC (`:115`).
  Trade state is lost on restart.

## Verdict & next step
Long-only on gold worked while gold went from about $2,000 to $4,000+ (2023–2026). That's the market, not an edge. Test it on a flat or falling period
before trusting any result.

## Related
[common code traps](../concepts/common-code-traps.md) · [backtesting method](../concepts/backtesting-method.md) ·
[GoldAggressiveCompounder](gold-aggressive-compounder.md)
