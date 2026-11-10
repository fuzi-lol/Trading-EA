# YT_Strategies – Backtest Results

Four popular YouTube forex strategies, coded into one EA (`YT_Strategies.mq5`) and backtested in MT5.

- **Account:** $10,000 start, 1:500 leverage, FundingPips-SIM1 server
- **Risk:** fixed 1% of the starting balance per trade ($100, no compounding)
- **Reward:risk:** take-profit at 2× the stop distance (1:2)
- **Positions:** one open trade at a time per strategy
- **Model:** MT5 "1-minute OHLC" (not every tick)
- **Returns:** % of the $10k starting balance. "Trades" counts completed trades.

## Strategies

| # | Strategy (YouTube source) | Timeframe | Rules as coded |
|---|---|---|---|
| 1 | **MACD + 200 EMA** (Trading Rush) | H1 | Buy when price is above the 200 EMA and the MACD lines cross upward below zero; sells are the mirror. Stop beyond the last 10-bar swing high/low (0.5–3× ATR). |
| 2 | **Triple EMA + Stochastic RSI + ATR** | H1 | EMAs 8/14/50 stacked in order, plus a Stochastic RSI K/D crossover. Stop at 1.5× ATR. |
| 3 | **London Breakout** (Asian-range breakout) | M15 | Mark the 00:00–08:00 UK high and low. Trade the first 15-minute close outside it between 08:00 and 11:00 UK. Stop at the middle of the range; anything still open is closed at 17:00 UK. |
| 4 | **Supertrend + 200 EMA** | H1 | Trade a Supertrend (10, 3) flip in the direction of the 200 EMA. Stop at the Supertrend line (up to 5× ATR). |

### Set files

| File | Use |
|---|---|
| `S1.set` – `S4.set` | Forex pairs, strategies 1–4 |
| `G1.set` – `G4.set` | Gold (XAUUSD): max spread 60 points; London Breakout Asian range $5–$40 |

---

## Gold (XAUUSD)

### 3 years: 25 Oct 2023 – 25 Oct 2026 (one continuous run per strategy)

| Strategy | **3-year return** | Trades | Win rate | Profit factor | **Max drawdown** | Profitable years |
|---|---|---|---|---|---|---|
| Triple EMA + Stoch RSI | **+27.66%** | 452 | 35.6% | 1.10 | 15.7% | 2 of 3 |
| MACD + 200 EMA | **+22.22%** | 177 | 38.4% | 1.23 | 14.1% | **3 of 3** |
| Supertrend + 200 EMA | **+20.04%** | 137 | 38.7% | **1.29** | **9.6%** | **3 of 3** |
| London Breakout | **+17.25%** | 342 | 41.2% | 1.10 | 20.5% | 2 of 3 |

### By year

| Strategy | Year 1: 25 Oct 2023 – 25 Oct 2024 | Year 2: 25 Oct 2024 – 25 Oct 2025 | Year 3: 25 Oct 2025 – 25 Oct 2026 |
|---|---|---|---|
| Triple EMA + Stoch RSI | **-3.30%** · 156 trades · WR 32.7% | +12.99% · 147 trades · WR 36.7% | +17.97% · 149 trades · WR 37.6% |
| MACD + 200 EMA | +8.09% · 63 trades · WR 38.1% | +2.97% · 56 trades · WR 35.7% | +11.17% · 58 trades · WR 41.4% |
| Supertrend + 200 EMA | +3.19% · 45 trades · WR 35.6% | +7.70% · 50 trades · WR 40.0% | +9.15% · 42 trades · WR 40.5% |
| London Breakout | +18.11% · 165 trades · WR 41.8% | **-10.09%** · 132 trades · WR 37.9% | +9.22% · 45 trades · WR 48.9% |

WR is the win rate. Years are split from the trades in the 3-year runs, so they can differ by a few tenths of a percent from separate 1-year runs.

### Last 2 months

| Strategy | 1 Sep – 1 Oct 2026 | 1 Oct – 26 Oct 2026 | **Combined** |
|---|---|---|---|
| Supertrend + 200 EMA | +1.42% · 2 trades · WR 50.0% · DD 1.6% | +2.30% · 3 trades · WR 66.7% · DD 2.1% | **+3.72%** · 5 trades |
| MACD + 200 EMA | +3.00% · 7 trades · WR 57.1% · DD 1.8% | -1.06% · 4 trades · WR 25.0% · DD 2.4% | **+1.94%** · 11 trades |
| London Breakout | +0.77% · 8 trades · WR 50.0% · DD 3.7% | -1.33% · 6 trades · WR 33.3% · DD 2.8% | **-0.56%** · 14 trades |
| Triple EMA + Stoch RSI | **-10.31%** · 12 trades · WR 0% · DD 10.5% | -0.14% · 9 trades · WR 33.3% · DD 4.1% | **-10.45%** · 21 trades |

DD is the maximum drawdown. Monthly results rest on only 2–12 trades and are mostly noise. A trade still open on the last day of a window is closed when the test ends.

---

## Forex

### Last year: 25 Oct 2025 – 25 Oct 2026 (return · trades)

| Pair | MACD + 200 EMA | Triple EMA + Stoch RSI | London Breakout | Supertrend + 200 EMA |
|---|---|---|---|---|
| EURUSD | -7.81% (77) | +5.09% (153) | **+12.61% (160)** | -3.24% (48) |
| GBPUSD | -10.49% (71) | -19.43% (161) | +2.50% (187) | +6.03% (43) |
| USDJPY | +5.15% (64) | -34.65% (159) | +6.59% (98) | +1.36% (50) |
| AUDUSD | -8.46% (67) | +0.15% (168) | -11.36% (126) | -2.98% (46) |
| USDCAD | +10.79% (61) | +24.95% (173) | +10.41% (150) | +15.46% (46) |
| NZDUSD | -14.07% (67) | -4.60% (153) | +11.77% (144) | +8.67% (49) |
| **Average per pair** | **-4.15%** | **-4.75%** | **+5.42%** | **+4.22%** |
| **Total trades** | 407 | 967 | 865 | 282 |

### Year before: 25 Oct 2024 – 25 Oct 2025 (return · trades)

Only the strategies that were profitable last year were re-tested here, plus all 4 on USDCAD.

| Pair | MACD + 200 EMA | Triple EMA + Stoch RSI | London Breakout | Supertrend + 200 EMA |
|---|---|---|---|---|
| EURUSD | – | – | **+17.45% (171)** | -0.37% (51) |
| GBPUSD | – | – | -4.14% (177) | -5.00% (44) |
| USDJPY | – | – | +2.12% (47) | +1.93% (52) |
| AUDUSD | – | – | -12.64% (150) | -6.25% (43) |
| USDCAD | -2.56% (67) | -15.03% (162) | +1.65% (159) | -0.83% (40) |
| NZDUSD | – | – | +1.37% (147) | -7.72% (59) |
| **Average per pair** | – | – | **+0.97%** | **-3.04%** |

### USDCAD, both years

| Strategy | 25 Oct 2025 – 25 Oct 2026 | 25 Oct 2024 – 25 Oct 2025 | 2 years |
|---|---|---|---|
| MACD + 200 EMA | +10.79% · 61 trades · DD 7.5% | -2.56% · 67 trades · DD 16.0% | +8.23% · 128 trades |
| Triple EMA + Stoch RSI | +24.95% · 173 trades · DD 12.7% | -15.03% · 162 trades · DD 23.1% | +9.92% · 335 trades |
| London Breakout | +10.41% · 150 trades · DD 17.5% | +1.65% · 159 trades · DD 11.9% | +12.06% · 309 trades |
| Supertrend + 200 EMA | +15.46% · 46 trades · DD 4.8% | -0.83% · 40 trades · DD 8.8% | +14.63% · 86 trades |

All 4 were profitable on USDCAD last year but not the year before, so last year was mostly a favourable market rather than a lasting edge.

---

## Conclusions

1. **The best setup is gold with Supertrend + 200 EMA.** It was profitable in all 3 years (+3.2%, +7.7%, +9.2%), had the highest profit factor (1.29) and the lowest drawdown (9.6%), and made money in both of the last 2 months. It averages about 45 trades a year, so the sample is small.
2. **Gold with MACD + 200 EMA is the second choice.** It was also profitable in all 3 years (+22.2% total), with a 14.1% drawdown.
3. **Gold with Triple EMA + Stoch RSI made the most in total (+27.7%) but is volatile.** It lost money in year 1 and had a 12-trade losing streak in September 2026 (-10.3%).
4. **London Breakout was profitable on forex but not reliably on gold.** EURUSD made money in both years (+12.6% and +17.5%). On gold it swung from +18% to -10%.
5. **The trend strategies don't work on forex.** MACD and Triple EMA lost about 4–5% per pair on average over the last year.
6. **The edges are thin.** Win rates of 35–41% at 1:2 sit just above the 33% break-even win rate.

## Caveats

- Gold rose almost continuously over 2023–2026 (about $2,000 → $4,000+). The trend strategies benefited, and a flat gold market would likely hurt them.
- These runs used 1-minute bars. Re-run the best setups over every tick before trading them live.
- On gold, lot sizes round down to 0.01 steps, so losing trades cost about $78–98 (0.8–1%) instead of exactly $100.
- London Breakout assumes the broker server runs 2 hours ahead of UK time. This wasn't checked against the server.
- The Supertrend stop cap was raised from 3× to 5× ATR after the first run. At 3× ATR it filtered out nearly every trade.

*Generated 26 Oct 2026.*
