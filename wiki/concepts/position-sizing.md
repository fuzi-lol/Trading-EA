# Position sizing & the tick-value bug

**How the EAs size trades.** There are three styles in this repo:

| Style | EAs |
|---|---|
| Fixed lot (usually 0.10) | [SMC_Confluence](../strategies/smc-confluence.md), [AsianRangeOB](../strategies/asian-range-ob.md), [GoldLondon](../strategies/gold-london.md), [GoldenTime V5](../strategies/golden-time.md), [DoubleTrap](../strategies/double-trap.md), [RSI_Divergence](../strategies/rsi-divergence.md), [MultiTF_Scalper](../strategies/multitf-scalper.md), [M1_Momentum](../strategies/m1-momentum-scalper.md), [RangeEngulf V2](../strategies/range-engulf.md), the [SMC BOS family](../strategies/smc-bos-template-family.md) (default) |
| % risk via `SYMBOL_TRADE_TICK_VALUE` | [SMC_LumenTrades](../strategies/smc-lumentrades.md), [GoldEliteScalper](../strategies/gold-elite-scalper.md), [GoldAggressiveCompounder](../strategies/gold-aggressive-compounder.md), [LiquiditySweepScalper](../strategies/liquidity-sweep-scalper.md), [PropFirmScalper](../strategies/prop-firm-scalper.md) (risk mode), [EMA_VWAP](../strategies/ema-vwap-scalper.md), [GoldenTime_1845](../strategies/golden-time.md), [NAS100_ORB](../strategies/nas100-orb.md), [MultiSession](../strategies/multi-session-major-pairs.md) |
| % risk via `OrderCalcProfit` or contract size | [YT_Strategies](../strategies/yt-strategies.md), [YT_GoldScalpers](../strategies/yt-gold-scalpers.md) (`OrderCalcProfit`, % of the **initial** balance); [RangeEngulf V7–V9](../strategies/range-engulf.md) (contract size) |

Formula: `lot = riskMoney / ((slDistance / tickSize) × tickValue)`, then floored to `SYMBOL_VOLUME_STEP`.

## The FundingPips tick-value bug
[from report] In the FundingPips-SIM1 strategy tester, `SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)` returned **0 for XAUUSD**
([`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md)). Each EA reacts differently:

| Reaction when tick value = 0 | EAs |
|---|---|
| Returns lot 0 → **never trades** | SMC_LumenTrades (`:463`, [verified]), GoldEliteScalper (`:1304`), PropFirmScalper (`:489`), EMA_VWAP (`:408`), GoldenTime_1845 (`:285`) |
| Silently falls back to `FixedLot` | LiquiditySweepScalper (`:614-619`, added after the report), SMC BOS family, NAS100_ORB (`:475-476`) |
| Falls back to "$1 per point per lot" | GoldAggressiveCompounder (`:475-481`): right for 2-digit gold, 10× too big on 3-digit |

The report's advice "set `UseFixedLot=true`" only works for EAs that **have** that input. SMC_LumenTrades doesn't.

**`OrderCalcProfit`** (used by the YT EAs) asks the server for the profit of a hypothetical trade, so it doesn't depend on the tick value. That makes it the more robust way to size.

## Related problems
- **Non-USD tick value:** the [MultiSession](../strategies/multi-session-major-pairs.md) USDJPY row looks like it was sized with an unconverted JPY tick value
  (losses of about $6 instead of about $1,000) [inference].
- **Raising to the minimum lot:** most EAs raise a too-small lot to `SYMBOL_VOLUME_MIN`. On small accounts or wide stops that risks more than the stated %.
- **Sizing before the SL is final:** [NAS100_ORB](../strategies/nas100-orb.md) computes the lot, then widens the SL.
- **Rule for new code:** size with `OrderCalcProfit`, size *after* the final SL is known, and refuse to trade (and log why) rather than silently change the risk.
