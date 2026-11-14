---
name: YT_GoldScalpers (+ Gold_RSI_EMA200, Gold_BB_RSI)
files: [YT_GoldScalpers/YT_GoldScalpers.mq5, YT_GoldScalpers/Gold_RSI_EMA200.mq5, YT_GoldScalpers/Gold_BB_RSI.mq5, YT_GoldScalpers/RESULTS.md, YT_GoldScalpers/GS1.set, YT_GoldScalpers/GS2.set, YT_GoldScalpers/GS3.set, YT_GoldScalpers/GS4.set, YT_GoldScalpers/GS5.set, YT_GoldScalpers/opt_rsi.set, YT_GoldScalpers/opt_bb.set, YT_GoldScalpers/tune/]
market: XAUUSD
timeframe: M5
family: multi-strategy (indicator scalps)
origin: youtube
verdict: no-edge (tuning failed out-of-sample; RESULTS says "not tradeable")
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# YT_GoldScalpers

Five YouTube gold-scalping strategies in one EA (`GS1–GS5.set`). The two that looked best were split into standalone EAs and then put through a
proper in-sample / out-of-sample tuning test. **Both failed it.** That makes this the repo's most useful *negative* result.

## The five strategies (as the code does them)
S1–S4 trade only between server hours 9 and 20 (`YT_GoldScalpers.mq5:194-199`). The SL must be 0.5–3 ATR from entry (`:154-158`), except for S5.
| # | Strategy | Entry | Exit |
|---|---|---|---|
| 1 | RSI 30/70 + 200 EMA | RSI(14) crosses **below** 30 (bars 2→1) and close > EMA200; mirror for sells (`:211-214`) | 1 ATR SL; TP 2 R |
| 2 | Bollinger(20,2) + RSI | bar 2 closed outside the band with RSI beyond 30/70, bar 1 back inside (`:229`, `:235`) | SL at the 3-bar extreme ± 0.2 ATR; TP at the middle band (needs ≥ 0.7 R) |
| 3 | VWAP + EMA20/50 pullback | close > VWAP (tick-volume, from server day start), EMA20 > EMA50, bar-1 low touched EMA20 and closed bullish (`:247-273`) | 1.5 ATR; half off at 1 R + BE (`:170-191`); TP 2 R |
| 4 | Fractal + EMA 20/50/100 | 5-bar fractal at bar 3 (confirmed, no look-ahead) with stacked EMAs (`:293-307`) | SL *at* EMA50/100 (`:299`, `:305`); TP 1.5 R |
| 5 | NY open 15-min ORB | M1 range 16:30–16:44 server (assumes UK+2, `:326-334`); first M5 close beyond it until 19:59 | SL at the other side; TP 2 R; flat at 22:00 |

The standalone **`Gold_RSI_EMA200.mq5`** (= S1) and **`Gold_BB_RSI.mq5`** (= S2) add optional HTF trend, min/max SL %, BE, trailing, daily cap,
cooldown, wrap-around sessions, and (BB) TP modes and an ADX limit.

## Sizing & risk
1% of the **initial** balance via `OrderCalcProfit`, capped at 90% of free margin (`:137-139`).

## Backtest evidence
[from report] [RESULTS.md](../../YT_GoldScalpers/RESULTS.md), every tick, $10k, 1%:
- Combined EA, 2025.10.26–2026.10.26: S1 **+$1,411, PF 1.48, DD 8.4%, 57 deals**; S2 +$243, PF 1.01, DD 25.2%; S3 **-$7,111**, PF 0.88, DD 74.4%;
  S4 **-$6,822**, PF 0.85, DD 71.4%; S5 -$103, PF 0.99.
- `Gold_RSI_EMA200`, 2 years (2024.10.28–2026.10.28): +$1,786, PF 1.33, DD 9.1%, 106 deals.
- `Gold_BB_RSI`, 2 years: -$1,069, PF 0.98, DD 30%.
- **Tuning test (in-sample 2023.01–2025.06, out-of-sample 2025.07–2026.10):** every tuned variant flipped sign. Example: RSI on M15 at all hours, +$2,451 in-sample → -$1,255
  out-of-sample. RESULTS' conclusion: "no robust edge; tuned params are curve-fit. Not tradeable."

## Issues found in code
- [unverified] S3's partial close and BE move don't check their results (`:189-190`). If the modify fails, the trade gets halved again on the next tick.
- [unverified] S5 and the London Breakout in [YT_Strategies](yt-strategies.md) share the "rejected entry still marks the day traded" trap (`:339-340`).
- [unverified] `Gold_BB_RSI` break-even depends on the global `g_risk`, which is lost on restart.
- [unverified] Several `tune/` sets (b2*, bH, bI, bK, bL, bM) repeat `InpMaxSpreadPts` or list inputs out of order. By RESULTS' own rule, MT5 may have silently ignored
  their overrides. The `v_*` sets are the clean, full reruns.

## Verdict & next step
Done: an honest negative result. S1 (RSI + EMA200) is the only survivor, and its edge is unstable across periods. Use this folder as the **template for
how to test**: an in-sample / out-of-sample split, every tick, and complete .set files.

## Related
[backtesting method](../concepts/backtesting-method.md) · [YT_Strategies](yt-strategies.md) · [NAS100_ORB](nas100-orb.md) (same ORB idea)
