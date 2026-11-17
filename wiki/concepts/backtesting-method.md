# Backtesting method & lessons

What earlier test runs taught. Follow this before believing or adding any result.

## Setup used so far
- MetaTrader 5 Strategy Tester (Build 6259), server **FundingPips-SIM1**, $10,000, 1:500 leverage, usually XAUUSD. Earlier sessions drove it through an
  `mt5-quant` MCP server ([`Backtest_Report_Oct2026.md`](../../Backtest_Report_Oct2026.md) footer). The MT5 genetic optimizer "is broken in this setup", so tuning
  meant single runs ([YT_GoldScalpers RESULTS](../../YT_GoldScalpers/RESULTS.md)).
- Models: **every tick** (YT_GoldScalpers, SMC_Confluence variants) vs **1-minute OHLC** (YT_Strategies). Results from 1-minute OHLC need an every-tick rerun.

## Lessons (from this repo's own results)
1. **In-sample tuning doesn't survive.** YT_GoldScalpers split the data into 2023.01–2025.06 (in-sample) and 2025.07–2026.10 (out-of-sample). Every tuned variant flipped
   sign. The SMC_Confluence V1–V8 sweep has **not** been tested this way yet.
2. **Win rate is a trap.** The three highest-win-rate EAs in the Oct report (82%, 73%, 65%) all lost money. Small trailed wins plus rare big losses = PF < 1.
   [MultiSession](../strategies/multi-session-major-pairs.md)'s 5-pip trail does the same thing.
3. **Small samples prove nothing.** RangeEngulf (9–14 trades/year), GoldLondon (5–21), GoldenTime (2), and monthly tables built on 2–12 trades.
4. **Gold rose from about $2,000 to $4,000+ (2023–2026).** Long-biased and trend strategies look good for that reason alone. Test a flat or falling stretch too.
5. **Check that the numbers add up.** Average loss ≈ net ÷ (PF − 1) ÷ number of losers should fit the stated deposit and risk %, and one loss can't exceed max DD. The
   MultiSession rows fail this check (see its page).
6. **Sums of separate single-pair runs aren't a portfolio result.**
7. **Trails or partials that never fire make "variant" comparisons meaningless.** Check the exit code before sweeping exit inputs
   ([SMC_Confluence](../strategies/smc-confluence.md), [MultiTF](../strategies/multitf-scalper.md), [GoldenTime](../strategies/golden-time.md)).

## `.set` file gotchas
- [from report] **A `.set` file must list ALL inputs, in declaration order, with no duplicates**, or MT5 silently ignores the overrides (YT_GoldScalpers RESULTS,
  last line). The fix used then was a script that generates complete .set files (a scratch `mkset.py`, not saved in the repo).
- Several sets here are partial (YT_Strategies S/G), alphabetical (SMC_LumenTrades, RSI_Divergence, MT5's own UTF-16 saves), contain duplicates (some `YT_GoldScalpers/tune/b*`),
  or name inputs that don't exist (`EMA_TF` in `SMC_V*.set`; `optimize_v8.set` targets an older M1_MomentumScalper). [unverified] whether each one's overrides took effect.
- Prefer saving sets from MT5's own "Save" button after loading, and record in RESULTS which set file and which commit produced each number.

## Checklist for a new result
Every tick · 2+ years · in-sample/out-of-sample split if anything was tuned · deposit and risk stated · the raw result saved to a file in the repo · the strategy page updated
with a link (see the *Ingest* workflow in `AGENTS.md`).
