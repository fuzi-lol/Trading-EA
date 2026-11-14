# Overview: what we have, what works, what's next

*Synthesis as of 2026-11-14 (commit 25e734f). Update this page when a verdict changes.*

## The big picture
- **30 own EA source files in 20 strategy pages**, plus one copied third-party EA (MultiSession) and a 77 MB third-party dump. Almost all target **XAUUSD on
  M1–M5**. The exceptions are MultiSession and YT_Strategies (forex majors) and NAS100_ORB.
- They fall into four kinds of idea:
  1. **SMC** (order blocks, FVGs, breaks of structure, sweeps): [SMC_Confluence](strategies/smc-confluence.md),
     [SMC_LumenTrades](strategies/smc-lumentrades.md), [SMC BOS family](strategies/smc-bos-template-family.md) (4 EAs),
     [AsianRangeOB](strategies/asian-range-ob.md), [GoldLondon](strategies/gold-london.md), [DoubleTrap](strategies/double-trap.md).
  2. **Session or clock-time breakouts:** [RangeEngulf](strategies/range-engulf.md), [GoldenTime](strategies/golden-time.md),
     [NAS100_ORB](strategies/nas100-orb.md), [MultiSession](strategies/multi-session-major-pairs.md), plus London Breakout and NY ORB inside the YT EAs.
  3. **Indicator rules from YouTube:** [YT_Strategies](strategies/yt-strategies.md), [YT_GoldScalpers](strategies/yt-gold-scalpers.md),
     [RSI_Divergence](strategies/rsi-divergence.md), [MultiTF_Scalper](strategies/multitf-scalper.md).
  4. **Multi-signal M1/M5 scalpers:** [GoldEliteScalper](strategies/gold-elite-scalper.md), [GoldAggressiveCompounder](strategies/gold-aggressive-compounder.md),
     [LiquiditySweepScalper](strategies/liquidity-sweep-scalper.md), [PropFirmScalper](strategies/prop-firm-scalper.md),
     [EMA_VWAP_Scalper](strategies/ema-vwap-scalper.md), [M1_MomentumScalper](strategies/m1-momentum-scalper.md).

## What the evidence says
**No EA has a proven, robust edge yet.** The best candidates, ranked by how much the evidence can be trusted:
1. **[YT_Strategies](strategies/yt-strategies.md) Supertrend + 200 EMA on gold:** 3/3 profitable years, PF 1.29, DD 9.6%, 137 trades. It's the strongest evidence, but
   it was tested on 1-minute OHLC while gold kept rising. MACD + 200 EMA is a close second.
2. **[SMC_Confluence](strategies/smc-confluence.md):** 1 year +$2,061, PF 1.51, 121 trades, but in-sample only, and its trailing code is dead.
3. **[RangeEngulf V9](strategies/range-engulf.md):** PF 2.03, but only 14 trades. Probably an 08:30-New-York news-candle setup (if the server clock is UTC+2/+3 [inference]).
4. **[YT_GoldScalpers](strategies/yt-gold-scalpers.md) S1 (RSI + EMA200):** positive over 2 years, but tuning flipped sign out of sample.

**The Oct report's #1, [MultiSession](strategies/multi-session-major-pairs.md), isn't reliable evidence.** It's third-party code, the per-trade losses imply about a
$100k deposit (not the stated $10k), the USDJPY row looks like a sizing artifact, and PF is 1.03–1.17 on the pairs that carry the total.

**Clear losers or not testable:** EMA_VWAP (DD 50.8%), MultiTF, PropFirmScalper, GoldenTime (README: net negative over 2 years), GoldLondon (stale filters, about 5
trades/year), SMC_LumenTrades (0 trades), NAS100_ORB (tick-counter bug). From the Oct report, the third-party NightScalper, EliteScalper2 and XANDER_Grid all lost; the grid lost the
whole account.

**No backtest on record:** the SMC BOS family (4 EAs), DoubleTrap, RSI_Divergence V1/V2, M1_MomentumScalper v10, GoldAggressiveCompounder.

## Problems found across the code
See [common code traps](concepts/common-code-traps.md). The ones that change results:
- **Exits that never run:** the trailing in SMC_Confluence and MultiTF, and the partials in GoldenTime. Exit-parameter "variants" of these EAs tested nothing.
- **Sizing:** the FundingPips tester returns tick value 0 on gold ([position sizing](concepts/position-sizing.md)). GoldAggressiveCompounder risks 3% per trade with
  no loss guard.
- **Clock:** every session hour is raw server time with no DST handling ([server time](concepts/server-time.md)).
- **SMC names vs code:** zones are rarely tied to the structure break, and entries are at market ([SMC terms as coded](concepts/smc-terms-as-coded.md)).

## Suggested next steps (in order)
1. Rerun Supertrend + 200 EMA and MACD + 200 EMA on gold **every tick**, and on a flat or falling stretch (for example 2021–2022).
2. Fix the SMC_Confluence trailing, then run the **baseline** out of sample (2023–2025) before comparing the V1–V8 variants.
3. Rerun MultiSession on EURUSD/NZDUSD with a stated $10k deposit, a fixed lot and every tick, after fixing the early-return bug. Or drop it as third-party.
4. Run RangeEngulf V9 over 2023–2026 to get a real trade count.
5. Stop adding new M1 scalpers until one of the above clears [the checklist](concepts/backtesting-method.md).
