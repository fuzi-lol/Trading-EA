---
name: YT_Strategies (4 YouTube strategies in one EA)
files: [YT_Strategies/YT_Strategies.mq5, YT_Strategies/RESULTS.md, YT_Strategies/S1.set, YT_Strategies/S2.set, YT_Strategies/S3.set, YT_Strategies/S4.set, YT_Strategies/G1.set, YT_Strategies/G2.set, YT_Strategies/G3.set, YT_Strategies/G4.set]
market: XAUUSD + 6 forex majors
timeframe: H1 (London Breakout on M15)
family: multi-strategy (indicator + session-breakout)
origin: youtube
verdict: promising on gold (Supertrend + 200 EMA, MACD + 200 EMA) — thin edge, 1-min-OHLC tests only
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# YT_Strategies

One EA that holds four popular YouTube strategies, picked with an input (`S1–S4.set` for forex, `G1–G4.set` for gold). It has the **best-documented testing in
the repo** ([RESULTS.md](../../YT_Strategies/RESULTS.md): 3 years on gold, 2 years on forex).

## The four strategies (as the code does them)
| # | Strategy | Entry | Stop / target |
|---|---|---|---|
| 1 | MACD + 200 EMA (H1) | close[1] > EMA200, MACD crossed its signal between bars 2→1, MACD[1] < 0 (`YT_Strategies.mq5:166-167`) | 10-bar swing, kept within 0.5–3 ATR; TP 2 R (`:173-183`) |
| 2 | Triple EMA + Stoch RSI (H1) | EMA 8 > 14 > 50, close[1] > EMA8, StochRSI K crosses D with K[2] < 50 (`:231`). RESULTS leaves out the last two conditions | 1.5 ATR; TP 2 R |
| 3 | London Breakout (M15) | 00:00–07:59 **UK** range (assumes server = UK+2, `:245`, `:253-255`), first M15 close outside it from 08:00 to 11:59 UK (RESULTS says to 11:00) | range midpoint; TP 2 R; flat at 17:00 UK (`:248`, `:324`) |
| 4 | Supertrend(10,3) + 200 EMA (H1) | Supertrend flip between bars 2→1 in the EMA200 direction (`:309-313`); skipped if the line is > `MaxSL_ATR` away (5 in the sets) | the Supertrend line (≥ 0.5 ATR); TP 2 R |

## Sizing & risk
1% of the **initial** balance (no compounding) via `OrderCalcProfit` (`:119-133`), floored to the lot step. One position at a time. The spread is checked only on the first
tick of a bar (`:139`).

## Backtest evidence
[from report] [RESULTS.md](../../YT_Strategies/RESULTS.md), 1-minute OHLC model, $10k, FundingPips-SIM1:

**Gold, 3 years (25 Oct 2023 – 25 Oct 2026):**
| Strategy | Return | Trades | PF | Max DD | Profitable years |
|---|---|---|---|---|---|
| Triple EMA + Stoch RSI | +27.66% | 452 | 1.10 | 15.7% | 2 of 3 |
| MACD + 200 EMA | +22.22% | 177 | 1.23 | 14.1% | 3 of 3 |
| Supertrend + 200 EMA | +20.04% | 137 | 1.29 | 9.6% | 3 of 3 |
| London Breakout | +17.25% | 342 | 1.10 | 20.5% | 2 of 3 |

**Forex, last year (average per pair):** MACD -4.15%, Triple EMA -4.75%, London Breakout +5.42%, Supertrend +4.22%. London Breakout on
EURUSD was positive in both years (+12.61%, +17.45%).

RESULTS' own caveats: gold roughly doubled over 2023–2026, which flatters the trend strategies; there was no every-tick rerun; win rates of 35–41% at 1:2 are just above the 33%
break-even.

## Issues found in code
- [unverified] London Breakout sets `g_lbTraded = true` even when `Open()` gives up (spread, minimum lot) (`:266-267`), so one rejected entry loses the whole day.
- [unverified] Order results aren't checked (`:149-150`). `g_initBalance` resets on re-init (`:72`).
- [unverified] The S/G .set files are partial. If MT5 drops partial or out-of-order overrides ([backtesting method](../concepts/backtesting-method.md)), some runs may
  not have used the intended values. RESULTS' match with code defaults suggests they did apply, but nobody checked.

## Verdict & next step
Clean code and honest testing. **Supertrend + 200 EMA on gold** is the most robust single result in the repo (3/3 years, PF 1.29, DD 9.6%). The next step
is RESULTS' own: rerun it every tick, and on a non-trending gold period (for example 2021–2022).

## Related
[backtesting method](../concepts/backtesting-method.md) · [YT_GoldScalpers](yt-gold-scalpers.md) (sister EA, M5 scalps) ·
[MultiSession](multi-session-major-pairs.md) (another Asian-range breakout)
