---
name: SMC_Confluence
files: [SMC_Confluence/SMC_Confluence.mq5, SMC_V1_RR2_ATR1.set, SMC_V2_RR2_ATR15.set, SMC_V3_RR3_ATR15.set, SMC_V4_RR25_ATR2.set, SMC_V5_RR2_1trade.set, SMC_V6_RR25_NYonly.set, SMC_V7_RR2_tightOB.set, SMC_V8_conservative.set, SMC_Confluence/backtest_results/comparison_results.md]
market: XAUUSD
timeframe: M5 chart (signals from M15 + H1)
family: smc
origin: own
verdict: promising (best own gold EA in the Oct report, but in-sample only)
source_commit: 25e734f
last_reviewed: 2026-11-14
---
# SMC_Confluence (v3.00)

Despite the name, this is mainly an **EMA-crossover trend system**: an M15 EMA 9/21 cross in the H1 trend
direction, with RSI bounds. The "smart money" pieces (fair value gap or order block, plus a break of structure) act as loose
extra filters. It trades a fixed 0.10 lot at most 2 times a day, only in London and New York hours.

## Entry (as the code does it)
- **Trend trigger:** M15 EMA 9 crosses EMA 21, checked on closed bars 1 and 2 (`SMC_Confluence.mq5:169-203`).
- **Higher-timeframe bias:** bid above (buy) / below (sell) the H1 EMA 50 (`:198-209`). The EMA 50/200 relation only feeds a log score (`:284`).
- **RSI band:** M15 RSI between 45 and 80 for buys, 20 to 55 for sells. H1 RSI ≥40 for buys, ≤60 for sells (`:212-221`).
- **SMC filter:** (an FVG **or** an order block) **and** a break of structure (BOS) (`:242-245`). All three use the chart timeframe (`PERIOD_CURRENT`), not M5 as the comments say.
  - FVG: `rates[i].low > rates[i-2].high`, within 2 ATR of price. There is no "unfilled" check, despite the comment (`:486-497`).
  - Order block: a bearish candle followed by a bullish one with a body ≥1.5× bigger; the zone is the bearish body (`:560-573`).
  - BOS: the last closed bar closes past the newest 2-bar fractal (`:643-650`).
  - What these terms mean in this repo: [SMC terms as coded](../concepts/smc-terms-as-coded.md).
- **Time:** "killzones" 11–13 and 15–21 **server time**, Tuesdays skipped (`:450-453`). See [server time](../concepts/server-time.md).

## Exit
- SL = 1.5 × ATR, clamped to 200–1200 points, then tightened to the OB/FVG edge − 10 points. TP = 2.5 R (`:250-280`).
- Break-even at 1 R, locking +20 points (`:371-375`).
- Trailing is coded, but **it never runs**; see Issues.

## Sizing & risk
Fixed `LotSize = 0.10` (`:59`), `MaxTradesPerDay = 2`, `CooldownBars = 6` after a loss, `MaxSpreadPts = 50`. No daily-loss limit.

## Settings files
The eight root-level `SMC_V1…V8_*.set` files vary RR (2.0–3.0), the ATR SL multiplier (1.0–2.0), trades/day, and session
(V6 turns London off with `LDN_Start = LDN_End = 23`). They also vary SMC tightness (V7) and use an all-conservative mix (V8).
The files also carry `EMA_TF=PERIOD_M15`, which is **not an input** of this EA, so MT5 ignores it.

## Backtest evidence
From [`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) (FundingPips-SIM1, $10,000, 1:500) [from report]:
- 1 year 2025.10.15–2026.10.15: **+$2,061, PF 1.51, win rate 55.4%, max DD 13.3%, 121 trades**.
- 1 month 2026.09.15–2026.10.15: +$237, PF 1.78, 12 trades.

From [`backtest_results/comparison_results.md`](../../SMC_Confluence/backtest_results/comparison_results.md)
(XAUUSD M5, Oct 2025–Oct 2026, every tick) [from report]:

| Variant | Profit | DD% | PF | Trades |
|---|---|---|---|---|
| Baseline (RR 2.5, ATR 1.5×) | $2,026 | 14.4% | 1.53 | 119 |
| V2 RR 2.0, ATR 1.5× | $1,827 | 10.7% | 1.46 | 121 |
| V4 RR 2.5, ATR 2.0× | $2,106 | 15.6% | 1.53 | 118 |
| V6 RR 2.5, NY only | $1,932 | 12.7% | 1.58 | 101 |
| V8 conservative | -$431 | 11.7% | 0.77 | 64 |

**Caution:** all variants were tuned and judged on the **same single year** (in-sample). The YT_GoldScalpers tuning
in this repo showed that edges found this way flipped sign out of sample
([backtesting method](../concepts/backtesting-method.md)). About 120 trades is a small sample. No out-of-sample or
multi-year run is on record.

## Issues found in code
- **[verified] The trailing stop is dead code.** Before break-even, the BE branch (`:371`) wins, because the trail is an `else if`
  and `Trail_Trigger_RR` (2.0) > `BE_Trigger_RR` (1.0). After break-even the SL is beyond the entry, so
  `slDist = posOpen - posSL` is ≤ 0 and `if(slDist <= 0) continue;` (`:360`) skips the position. **So the `Trail_*` changes
  in V1–V8 did nothing;** those variants really differ only in their other inputs.
- [unverified] The loss cooldown is set by **any** losing deal on the account (`OnTradeTransaction` `:413-425` has no
  magic/symbol filter) and uses `DEAL_PROFIT` without commission or swap.
- [unverified] On an M5 chart the same M15 cross (bar 1) is re-evaluated on three M5 bars.
- `gLastEntrySL` is set but never used (`:296`).

## Verdict & next step
The best own XAUUSD result so far, but it is in-sample, 1 year, about 120 trades. Next: (1) fix the trailing logic or delete
the inputs; (2) run 2023–2025 as an out-of-sample test with the baseline settings unchanged; (3) only then compare V2/V6.

## Related
[SMC terms as coded](../concepts/smc-terms-as-coded.md) · [backtesting method](../concepts/backtesting-method.md) ·
[server time](../concepts/server-time.md) · sibling: [AsianRangeOB](asian-range-ob.md) (same coding style and OB definition)
