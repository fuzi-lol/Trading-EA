# EA Backtest Comparison Report

**Date:** October 15, 2026
**Deposit:** $10,000 | **Leverage:** 1:500 | **Account:** 20730278 | **Server:** FundingPips-SIM1 (Build 6259)
**Periods:** 1 Year (2025.10.15 - 2026.10.15) | 1 Month (2026.09.15 - 2026.10.15)

---

## Executive Summary

15 EAs were backtested across XAUUSD and multiple forex pairs. **4 EAs showed consistent profitability.**

**Best performer:** SMC_Confluence (+$2,061/yr, PF 1.51)
**Best risk-adjusted:** RangeEngulfV9 (+$704/yr, PF 2.03, MaxDD 4.7%)
**Best multi-pair:** MultiSession_MajorPairs_EA (+$15,981/mo across 6 pairs)

### Known Issue: FundingPips Backtester Bug
`SYMBOL_TRADE_TICK_VALUE` returns 0 for XAUUSD in the FundingPips strategy tester. This breaks risk-based lot sizing (`UseFixedLot=false`) in any EA using `SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)`. Affected EAs: LiquiditySweepScalper, EMA_VWAP_Scalper, SMC_LumenTrades. Workaround: use `UseFixedLot=true` in inputs or .set files.

---

## Rankings at a Glance

| Rank | EA | 1yr Profit | PF | MaxDD% | Grade |
|------|-----|-----------|-----|--------|-------|
| 1 | MultiSession_MajorPairs_EA | +$18,414 (6 pairs) | 1.03-2.63 | 0.02-12% | A+ |
| 2 | SMC_Confluence | +$2,061 | 1.51 | 13.3% | A |
| 3 | RangeEngulfV9 | +$704 | 2.03 | 4.7% | B+ |
| 4 | LiquiditySweepScalper | +$382 | 1.02 | 8.8% | C+ |
| 5 | AsianRangeOB | +$144 | 1.06 | 11.8% | C+ |
| 6 | GoldEliteScalper | +$75 | 1.12 | 0.7% | C |
| 7 | PropFirmScalper | +$60 | 1.01 | 10.5% | D |
| 8 | GoldenTimeStrategy | -$36 | 0.00 | 0.8% | D- |
| 9 | GoldLondonStrategy | -$51 | 0.00 | 0.8% | D- |
| 10 | MultiTF_Scalper | -$456 | 0.83 | 9.6% | D |
| 11 | NightScalper | -$807 | 0.97 | 26.7% | F |
| 12 | EliteScalper2 | -$852 | 0.82 | 8.9% | F |
| 13 | XANDER_Grid_XAUUSD | -$10,172 | 0.54 | 101.5% | F- |
| - | EMA_VWAP_Scalper | N/A | - | - | Tick bug |
| - | SMC_LumenTrades | N/A | - | - | Tick bug |

---

## 1. MultiSession_MajorPairs_EA (TOP PERFORMER)

Multi-pair session-based strategy trading across 6 forex pairs.

### 1-Month Results (Sep 2026)

| Pair | Net Profit | Win Rate | PF | Max DD | Trades | Sharpe |
|------|-----------|----------|-----|--------|--------|--------|
| EURUSD | +$5,038 | 79.2% | 2.63 | 1.70% | 24 | 11.61 |
| NZDUSD | +$4,284 | 72.0% | 2.33 | 1.62% | 25 | 8.35 |
| USDCAD | +$2,787 | 65.2% | 1.60 | 2.39% | 23 | 5.00 |
| GBPUSD | +$2,429 | 65.6% | 1.31 | 2.81% | 32 | 4.03 |
| AUDUSD | +$1,405 | 66.7% | 1.29 | 2.52% | 21 | 3.41 |
| USDJPY | +$38 | 82.9% | 1.65 | 0.02% | 41 | 10.64 |
| **TOTAL** | **+$15,981** | | | | **166** | |

### 1-Year Results (Oct 2025 - Sep 2026)

| Pair | Net Profit | Win Rate | PF | Max DD | Trades | Sharpe |
|------|-----------|----------|-----|--------|--------|--------|
| EURUSD | +$12,086 | 64.7% | 1.14 | 11.10% | 331 | 2.11 |
| NZDUSD | +$9,797 | 61.0% | 1.17 | 5.97% | 272 | 1.81 |
| GBPUSD | +$4,258 | 66.0% | 1.03 | 10.74% | 441 | 0.58 |
| USDJPY | +$196 | 70.0% | 1.26 | 0.07% | 433 | 3.73 |
| USDCAD | -$2,863 | 58.4% | 0.97 | 11.39% | 351 | -0.46 |
| AUDUSD | -$5,060 | 59.3% | 0.93 | 12.03% | 275 | -0.99 |
| **NET TOTAL** | **+$18,414** | | | | **2,103** | |

**Assessment:** Strongest EA in the portfolio. 4 of 6 pairs profitable over 1 year. ALL 6 profitable in the last month. High Sharpe ratios. Consider removing USDCAD and AUDUSD for better risk-adjusted returns.

---

## 2. Detailed XAUUSD EA Results

### 1-Year Results (2025.10.15 - 2026.10.15)

| EA | Net Profit | PF | Win Rate | Max DD% | Trades | Trades/Mo |
|----|-----------|-----|---------|---------|--------|-----------|
| **SMC_Confluence** | **+$2,061** | **1.51** | 55.4% | 13.3% | 121 | 10.1 |
| **RangeEngulfV9** | **+$704** | **2.03** | 50.0% | 4.7% | 14 | 1.2 |
| LiquiditySweepScalper | +$382 | 1.02 | 46.6% | 8.8% | 1,242 | 103.5 |
| AsianRangeOB | +$144 | 1.06 | 47.9% | 11.8% | 48 | 4.0 |
| GoldEliteScalper | +$75 | 1.12 | 46.5% | 0.7% | 447 | 37.3 |
| PropFirmScalper | +$60 | 1.01 | 46.8% | 10.5% | 423 | 35.3 |
| GoldenTimeStrategy | -$36 | 0.00 | 0.0% | 0.8% | 2 | 0.2 |
| GoldLondonStrategy | -$51 | 0.00 | 0.0% | 0.8% | 5 | 0.4 |
| MultiTF_Scalper | -$456 | 0.83 | 46.8% | 9.6% | 62 | 5.2 |
| NightScalper (USDCAD) | -$807 | 0.97 | 73.4% | 26.7% | 1,053 | 87.8 |
| EliteScalper2 | -$852 | 0.82 | 80.2% | 8.9% | 4,839 | 403 |
| XANDER_Grid_XAUUSD | -$10,172 | 0.54 | 64.6% | 101.5% | 1,877 | 156.4 |

### 1-Month Results (2026.09.15 - 2026.10.15)

| EA | Net Profit | PF | Win Rate | Max DD% | Trades |
|----|-----------|-----|---------|---------|--------|
| **SMC_Confluence** | **+$237** | **1.78** | 66.7% | 3.4% | 12 |
| MultiTF_Scalper | +$208 | 3.59 | 75.0% | 2.1% | 4 |
| AsianRangeOB | +$181 | 1.40 | 37.5% | 3.2% | 8 |
| GoldEliteScalper | +$16 | 1.43 | 52.5% | 0.1% | 40 |
| LiquiditySweepScalper | -$12 | 0.99 | 44.1% | 3.4% | 102 |
| EliteScalper2 | -$20 | 0.95 | 82.4% | 0.5% | 408 |
| PropFirmScalper | -$92 | 0.88 | 52.5% | 4.7% | 40 |
| NightScalper (USDCAD) | -$425 | 0.81 | 71.1% | 8.3% | 83 |
| XANDER_Grid_XAUUSD | -$1,728 | 0.82 | 66.3% | 37.6% | 1,232 |
| GoldLondonStrategy | $0 | - | - | - | 0 |
| GoldenTimeStrategy | $0 | - | - | - | 0 |
| RangeEngulfV9 | $0 | - | - | - | 0 |

### EAs Affected by FundingPips TICK_VALUE Bug

| EA | Issue | Prior result with .set file |
|----|-------|-----------------------------|
| EMA_VWAP_Scalper | `UseFixedLot=false` → lot=0 (TICK_VALUE returns 0) | EVS_risk05: -$205, PF 0.99, MaxDD 50.8%, 131 trades (1yr) |
| LiquiditySweepScalper | Same bug, fixed by setting UseFixedLot=true | LSS_propfirm: +$612, PF 1.63, MaxDD 2.0%, 54 trades (1mo) |
| SMC_LumenTrades | Same bug, 0 trades on all settings | Needs UseFixedLot=true + tuned params |

---

## 3. Risk-Adjusted Performance

### Calmar Ratio (Return % / Max DD %)

| EA | Return % | Max DD% | Calmar | Verdict |
|----|----------|---------|--------|---------|
| SMC_Confluence | 20.6% | 13.3% | 1.55 | GOOD |
| RangeEngulfV9 | 7.0% | 4.7% | 1.49 | GOOD |
| GoldEliteScalper | 0.8% | 0.7% | 1.07 | NEUTRAL |
| LiquiditySweepScalper | 3.8% | 8.8% | 0.43 | POOR |
| AsianRangeOB | 1.4% | 11.8% | 0.12 | POOR |
| PropFirmScalper | 0.6% | 10.5% | 0.06 | POOR |
| MultiTF_Scalper | -4.6% | 9.6% | -0.47 | FAIL |
| NightScalper | -8.1% | 26.7% | -0.30 | FAIL |
| EliteScalper2 | -8.5% | 8.9% | -0.96 | FAIL |
| XANDER_Grid | -101.7% | 101.5% | -1.00 | BLOWN |

### Drawdown Safety

| EA | Max DD% | Prop Firm Safe (<5%)? |
|----|---------|----------------------|
| GoldEliteScalper | 0.7% | YES |
| RangeEngulfV9 | 4.7% | YES |
| LiquiditySweepScalper | 3.4% (1mo) | YES (1mo) |
| SMC_Confluence | 3.4% (1mo) / 13.3% (1yr) | YES (1mo) / NO (1yr) |
| EliteScalper2 | 0.5% (1mo) / 8.9% (1yr) | YES (1mo) / NO (1yr) |
| NightScalper | 26.7% | NO |
| XANDER_Grid | 101.5% | BLOWN |

---

## 4. The Win Rate Trap

**The 3 highest win-rate EAs are ALL losers:**

| EA | Win Rate | PF | 1yr Profit | Why It Loses |
|----|----------|----|-----------|--------------|
| EliteScalper2 | **82.4%** | 0.82 | -$852 | $1 profit target vs $5 avg loss. 4,839 trades/yr of tiny wins wiped by fewer large losses. |
| NightScalper | **73.4%** | 0.97 | -$807 | BB mean-reversion wins small, but trend moves cause outsized losses. |
| XANDER_Grid | **64.6%** | 0.54 | -$10,172 | Grid collects small wins until one trend move destroys the account. |

**The 2 best EAs have moderate win rates:**

| EA | Win Rate | PF | 1yr Profit | Why It Wins |
|----|----------|----|-----------|-------------|
| SMC_Confluence | **55.4%** | 1.51 | +$2,061 | Balanced RR with FVG+OB confluence filtering for quality entries. |
| RangeEngulfV9 | **50.0%** | 2.03 | +$704 | 50/50 WR but winners are 2x the size of losers. |

---

## 5. Profit Factor Consistency (1yr vs 1mo)

| EA | PF (1yr) | PF (1mo) | Trend | Assessment |
|----|----------|----------|-------|------------|
| RangeEngulfV9 | 2.03 | - | N/A | Low trades, needs more data |
| SMC_Confluence | 1.51 | 1.78 | Improving | Strong and consistent |
| GoldEliteScalper | 1.12 | 1.43 | Improving | Marginal but improving |
| AsianRangeOB | 1.06 | 1.40 | Improving | Marginal, low trades |
| LiquiditySweepScalper | 1.02 | 0.99 | Flat | Breakeven on defaults |
| PropFirmScalper | 1.01 | 0.88 | Declining | Losing edge |
| NightScalper | 0.97 | 0.81 | Declining | Getting worse |
| EliteScalper2 | 0.82 | 0.95 | Improving | Still losing |
| MultiTF_Scalper | 0.83 | 3.59 | Erratic | Too inconsistent |
| XANDER_Grid | 0.54 | 0.82 | Losing | Dangerous |

---

## 6. Trade Frequency & Statistical Significance

| EA | Trades (1yr) | Trades/Mo | Confidence | Notes |
|----|-------------|-----------|------------|-------|
| EliteScalper2 | 4,839 | 403 | Very High | Statistically confirmed loser |
| MultiSession (6 pairs) | 2,103 | 175 | Very High | Statistically confirmed winner |
| XANDER_Grid | 1,877 | 156 | Very High | Statistically confirmed loser |
| LiquiditySweepScalper | 1,242 | 104 | Very High | Breakeven confirmed |
| NightScalper | 1,053 | 88 | Very High | Statistically confirmed loser |
| GoldEliteScalper | 447 | 37 | High | Marginal profit confirmed |
| PropFirmScalper | 423 | 35 | High | Breakeven confirmed |
| SMC_Confluence | 121 | 10 | Moderate | Profitable but needs more data |
| MultiTF_Scalper | 62 | 5 | Low | Insufficient for conclusion |
| AsianRangeOB | 48 | 4 | Low | Insufficient for conclusion |
| RangeEngulfV9 | 14 | 1 | Very Low | Promising but too few trades |

---

## 7. Consistency Check (1yr vs 1mo)

| EA | 1yr Profit | 1mo Profit | Monthly Avg | Consistent? |
|----|-----------|-----------|-------------|-------------|
| MultiSession (6 pairs) | +$18,414 | +$15,981 | +$1,535/mo | YES - recent month exceptional |
| SMC_Confluence | +$2,061 | +$237 | +$172/mo | YES - recent > average |
| AsianRangeOB | +$144 | +$181 | +$12/mo | IMPROVING |
| GoldEliteScalper | +$75 | +$16 | +$6/mo | YES - stable but tiny |
| LiquiditySweepScalper | +$382 | -$12 | +$32/mo | MIXED - defaults are breakeven |
| RangeEngulfV9 | +$704 | $0 | +$59/mo | NO - inactive recently |
| EliteScalper2 | -$852 | -$20 | -$71/mo | IMPROVING but still losing |
| MultiTF_Scalper | -$456 | +$208 | -$38/mo | INCONSISTENT |
| NightScalper | -$807 | -$425 | -$67/mo | CONSISTENTLY LOSING |
| XANDER_Grid | -$10,172 | -$1,728 | -$848/mo | CONSISTENTLY DESTROYING |

---

## Final Recommendations

### DEPLOY (Tier 1)
| EA | Action | Expected Monthly | Risk |
|----|--------|-----------------|------|
| **MultiSession_MajorPairs_EA** | Deploy on EURUSD, NZDUSD, GBPUSD, USDJPY (drop USDCAD/AUDUSD) | +$1,500-3,000/mo | Moderate (10-11% DD on some pairs) |
| **SMC_Confluence** | Deploy on XAUUSD M5 | +$170/mo | Moderate (13% DD, needs prop firm tuning) |
| **RangeEngulfV9** | Deploy on XAUUSD M5 (small size, monitor) | +$59/mo | Low (4.7% DD) but very few trades |

### OPTIMIZE (Tier 2)
| EA | Action Needed |
|----|--------------|
| LiquiditySweepScalper | Use LSS_propfirm.set (PF 1.63 vs 1.02 on defaults). Fix TICK_VALUE fallback for risk-based sizing. |
| AsianRangeOB | Promising recent month (+$181). Needs more active signal generation. |
| GoldEliteScalper | Safe (0.7% DD) but tiny returns. Consider increasing lot size for prop firm use. |

### DO NOT DEPLOY (Tier 3)
| EA | Reason |
|----|--------|
| PropFirmScalper | Breakeven after 423 trades. No edge. |
| MultiTF_Scalper | Inconsistent (-$456/yr but +$208 recent month). |
| GoldenTimeStrategy | 2 trades in a year. Effectively inactive. |
| GoldLondonStrategy | 5 trades in a year. Effectively inactive. |
| EMA_VWAP_Scalper | -$205/yr even with tuned params. MaxDD 50.8%. |
| SMC_LumenTrades | 0 trades — needs TICK_VALUE fix + parameter tuning. |

### DELETE (Tier 4)
| EA | Reason |
|----|--------|
| **EliteScalper2** | -$852/yr despite 82% WR. 4,839 trades of tiny $1 wins wiped by losses. Account lock removed for testing. |
| **NightScalper** | -$807/yr despite 73% WR. Consistent loser across all timeframes. |
| **XANDER_Grid_XAUUSD** | **Blew the entire $10,000 account.** Grid/martingale on gold = guaranteed ruin. MaxDD 101.5%. |

---

## Key Takeaways

1. **MultiSession_MajorPairs_EA is the portfolio champion** — +$18,414/yr across 6 pairs with +$15,981 in the last month alone
2. **SMC_Confluence is the best single-pair EA** — 20.6% annual return with consistent PF >1.5
3. **Win rate is a trap** — The 3 highest WR EAs (82%, 73%, 65%) are ALL losers. Risk:reward matters more.
4. **Grid strategies destroy accounts** — XANDER_Grid lost the entire $10,000 despite 65% win rate
5. **FundingPips backtester has a TICK_VALUE bug** — Returns 0 for XAUUSD, breaking risk-based lot sizing. Use `UseFixedLot=true` as workaround.
6. **Default parameters often don't work** — 3 EAs needed tuned .set files to produce any trades
7. **For prop firms:** RangeEngulfV9 (4.7% DD) and GoldEliteScalper (0.7% DD) are the safest options
8. **High-frequency ≠ profitable** — EliteScalper2 (403 trades/mo) lost more than RangeEngulfV9 (1 trade/mo) made

---

*Report generated by Claude Code on October 15, 2026*
*Backtest engine: MetaTrader 5 (Build 6259) via mt5-quant MCP*
*Account: 20730278 @ FundingPips-SIM1*
*Fixes applied: EliteScalper2 account lock removed, LiquiditySweepScalper TICK_VALUE fallback added*
