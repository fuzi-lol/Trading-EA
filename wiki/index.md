# Trading-EA wiki: index

Read this first. One row per strategy page. Only claims tagged `[verified]` on a page were re-opened by hand; Entry/Exit descriptions come from full code reads by review agents.
Verdict key: **promising** (some positive evidence) · **marginal** (about break-even) · **no-edge** (loses) ·
**broken** (bugs stop it from working as intended) · **untested** (no backtest on record).
How this wiki is maintained: [`../AGENTS.md`](../AGENTS.md). History: [log.md](log.md). Synthesis and next steps: **[overview.md](overview.md)**.

## Strategies

| Page | EA file(s) | Market / TF | Idea in one line | Best result on record | Verdict |
|---|---|---|---|---|---|
| [YT_Strategies](strategies/yt-strategies.md) | `YT_Strategies.mq5` | XAUUSD + 6 FX majors / H1, M15 | 4 YouTube systems: MACD+200EMA, Triple EMA+StochRSI, London Breakout, Supertrend+200EMA | Gold Supertrend: +20.04% over 3 yrs, PF 1.29, DD 9.6% (1-min OHLC) | promising |
| [SMC_Confluence](strategies/smc-confluence.md) | `SMC_Confluence.mq5` + `SMC_V1–V8.set` | XAUUSD / M5 (M15, H1) | M15 EMA 9/21 cross in H1 trend + RSI band + FVG/OB + BOS, London/NY hours | +$2,061/yr, PF 1.51, DD 13.3% (in-sample) | promising |
| [RangeEngulf](strategies/range-engulf.md) | `RangeEngulfV2/V7/V8/V9.mq5` | XAUUSD / M1 | IST 12:30–17:30 range; engulfing candle at 15:30 server (likely 08:30 New York), fading the side of the range | V9: +$704/yr, PF 2.03, 14 trades | promising (tiny sample) |
| [YT_GoldScalpers](strategies/yt-gold-scalpers.md) | `YT_GoldScalpers.mq5`, `Gold_RSI_EMA200.mq5`, `Gold_BB_RSI.mq5` | XAUUSD / M5 | 5 YouTube scalps: RSI+EMA200, BB+RSI, VWAP pullback, fractal+EMAs, NY ORB | RSI+EMA200: +$1,786 over 2 yrs; tuning failed out-of-sample | no-edge |
| [MultiSession_MajorPairs](strategies/multi-session-major-pairs.md) | `MultiSession_MajorPairs_EA.mq5` (**third-party**) | FX majors / any TF | Asian-range breakout (am) + BB/RSI mean reversion (pm), 5-pip trail | "+$18,414" = sum of 6 runs; numbers inconsistent | unproven |
| [AsianRangeOB](strategies/asian-range-ob.md) | `AsianRangeOB.mq5` | XAUUSD / M5 | 1-hour early-Asian range breakout, enter on the order-block retest | +$144/yr, PF 1.06, 48 trades | marginal |
| [GoldEliteScalper](strategies/gold-elite-scalper.md) | `GoldEliteScalper.mq5` | XAUUSD / M1–M5 | ICT checklist: EMA, VWAP, CVD, sweep, FVG/OB, candle votes → score | +$75/yr, PF 1.12, DD 0.7% | marginal |
| [LiquiditySweepScalper](strategies/liquidity-sweep-scalper.md) | `LiquiditySweepScalper.mq5` | XAUUSD / M1 (M15 levels) | M1 wick through an M15 swing level, closes back → reverse | +$382/yr, PF 1.02 (1,242 trades) | marginal |
| [PropFirmScalper](strategies/prop-firm-scalper.md) | `PropFirmScalper.mq5` | XAUUSD / M1 | M1 FVG pullback in the trend during 1-hour kill zones, prop-firm guards | +$60/yr, PF 1.01 | no-edge |
| [EMA_VWAP_Scalper](strategies/ema-vwap-scalper.md) | `EMA_VWAP_Scalper.mq5` | XAUUSD / M1 | M1 EMA 9/21 cross + M5 EMA50 + VWAP + ADX/ATR/BB filters | -$205/yr, DD 50.8% | no-edge |
| [MultiTF_Scalper](strategies/multitf-scalper.md) | `MultiTF_Scalper.mq5` | XAUUSD / M5 | D1→M15 bias score + "M5" ribbon pullback (really M15) | -$456/yr, PF 0.83 | no-edge |
| [GoldenTime](strategies/golden-time.md) | `GoldenTimeStrategy.mq5`, `GoldenTime_1845.mq5` | XAUUSD / M1–M5 | Breakout of a 3-min zone at "18:45 IST" | net negative over 2 yrs (README) | no-edge |
| [GoldLondon](strategies/gold-london.md) | `GoldLondonStrategy.mq5`, `GoldLondonV3.mq5` | XAUUSD / H1 + M5 | London H1 range → liquidity grab → M5 FVG retest, target the other side | V3: +$56.50 over 2 yrs, 21 trades | broken (stale filters) |
| [SMC_LumenTrades](strategies/smc-lumentrades.md) | `SMC_LumenTrades.mq5` | XAUUSD / H1 + M5 | H1 ChoCH → H1 order block → M5 rejection entry, 1% risk | 0 trades (tick-value bug) | broken |
| [NAS100_ORB](strategies/nas100-orb.md) | `NAS100_ORB.mq5` | NAS100 / M1 | US-open range breakout + ATR, EMA, VWAP filters, partial at 1R | no backtest on record | broken |
| [SMC BOS family](strategies/smc-bos-template-family.md) | `SMC_2xBOS_BreakerBlock`, `SMC_2xBOS_BB_Scalp`, `SMC_3xBOS_Reversal`, `SMC_LiqSweep_OB_IFVG` | gold-sized / H1+M5, M5+M1, M15+M5 | One template: HTF structure (2x/3x BOS or sweep) + LTF confirmation, market entry | no backtest on record | untested |
| [DoubleTrap](strategies/double-trap.md) | `DoubleTrapStrategy.mq5` | XAUUSD / M15 | Double top/bottom at an S/R zone + wick trap → reversal | no backtest on record | untested |
| [RSI_Divergence](strategies/rsi-divergence.md) | `RSI_Divergence.mq5`, `RSI_Divergence_V2.mq5` | XAUUSD / M5 | RSI divergence in a zone + engulfing + H1 trend, staged RSI exits | no backtest on record | untested |
| [M1_MomentumScalper](strategies/m1-momentum-scalper.md) | `M1_MomentumScalper.mq5` | XAUUSD / M1 | Buy-only: 4 momentum signals above M5 EMA50 + VWAP | no backtest on record (v10) | untested |
| [GoldAggressiveCompounder](strategies/gold-aggressive-compounder.md) | `GoldAggressiveCompounder.mq5` | XAUUSD / M5 | 4 signals, **3% risk**, 5 positions, pyramiding, no loss guard | no backtest on record | untested (high risk) |

## Concepts
- [Position sizing & the tick-value bug](concepts/position-sizing.md): how each EA sizes trades, and what happens when the tester returns tick value 0.
- [Server time, IST and DST](concepts/server-time.md): what each hard-coded hour really means.
- [SMC terms as coded](concepts/smc-terms-as-coded.md): what BOS, OB, FVG, ChoCH and sweep mean in *this* code.
- [Backtesting method & lessons](concepts/backtesting-method.md): test setup, the .set-file gotcha, the checklist for new results.
- [Common MQL5 code traps](concepts/common-code-traps.md): bugs that repeat across EAs.

## Other
- [Third-party L0rdtrey folder](third-party-l0rdtrey.md): what the 77 MB dump is; where NightScalper, XANDER_Grid and EliteScalper2 live.

## Raw sources (never edited by the wiki)
[`Backtest_Report_Oct2026.md`](../Backtest_Report_Oct2026.md) · [`YT_Strategies/RESULTS.md`](../YT_Strategies/RESULTS.md) ·
[`YT_GoldScalpers/RESULTS.md`](../YT_GoldScalpers/RESULTS.md) · [`SMC_Confluence/backtest_results/comparison_results.md`](../SMC_Confluence/backtest_results/comparison_results.md) ·
[`RangeEngulfingStrategy/README.txt`](../RangeEngulfingStrategy/README.txt) · [`GoldLondonStrategy/README.txt`](../GoldLondonStrategy/README.txt) ·
[`GoldenTimeStrategy/README.txt`](../GoldenTimeStrategy/README.txt) · every `*.mq5` and `*.set`
