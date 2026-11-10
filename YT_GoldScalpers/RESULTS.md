# YT Gold Scalpers — XAUUSD M5, 2025.10.26–2026.10.26
Every-tick model, $10k, 1% of initial balance risk/trade (lot capped to 90% free margin; broker gold margin ~1:20).
Sets: GS1..GS5.set (InpStrategy 1..5). Session filter S1–S4: server 09–21.

| Strategy | Net $ | PF | MaxDD % | Deals |
|---|---|---|---|---|
| 1 RSI 30/70 + 200 EMA (1:2) | +1,411 | 1.48 | 8.4 | 57 |
| 2 Bollinger(20,2) + RSI → mid band | +243 | 1.01 | 25.2 | 550 |
| 3 VWAP + EMA20/50 pullback (½ at 1R, 2R) | -7,111 | 0.88 | 74.4 | 2,296 |
| 4 Fractal + EMA 20/50/100 (1.5R) | -6,822 | 0.85 | 71.4 | 867 |
| 5 NY open 15-min ORB (2R) | -103 | 0.99 | 15.1 | 219 |

Monthly $ (S1 / S2 / S3 / S4 / S5):
2025-10 -97/-298/-379/-194/+465 · 2025-11 -131/+88/-1491/-11/-119 · 2025-12 -325/+77/-640/-269/-439
2026-01 +680/+489/-1676/-1849/-417 · 2026-02 +76/+319/-403/-1306/+60 · 2026-03 +571/-1047/-419/+200/+773
2026-04 -9/+596/-598/-114/+54 · 2026-05 -139/+25/-261/+440/-223 · 2026-06 +199/+931/-3/-1064/+962
2026-07 -286/-1375/-774/-2087/-600 · 2026-08 +119/-443/+396/+232/+371 · 2026-09 +196/+416/-803/-187/-928
2026-10 +556/+463/-59/-613/-62

## Standalone EAs, 2-year test (2024.10.28–2026.10.28, every tick, $10k, 1%)
- Gold_RSI_EMA200.mq5: +$1,786, PF 1.33, MaxDD 9.1%, 106 deals, WR 38.7%. Oct24–Oct25 ≈ +$263, Nov25–Oct26 ≈ +$1,523. 13/24 months green.
- Gold_BB_RSI.mq5: -$1,069, PF 0.98, MaxDD 30%, 1,182 deals. Oct24–Oct25 ≈ -$1,936, Nov25–Oct26 ≈ +$867.

## Tuning attempt (2026-10-28) — FAILED out-of-sample
In-sample 2023.01.01–2025.06.30, out-of-sample 2025.07.01–2026.10.28, every tick, $10k, 1%. ~45 single backtests (MT5 genetic optimizer launch is broken in this setup).
Both EAs gained inputs: HTF trend filter, min SL %, BE, trail (RSI), ADX/TP modes/cooldown (BB), wrap-around session hours.

| Candidate | In-sample | Out-of-sample |
|---|---|---|
| RSI default (M5, 09–21) | -$1,478 PF 0.75 | (≈ profitable — see 2-yr run) |
| RSI M15, all hours | +$2,451 PF 1.34 | -$1,255 PF 0.69 |
| RSI M15, all hours, BE 1R | +$2,053 PF 1.39 | -$567 PF 0.78 |
| RSI M15, all hours, RR 1.5 | +$2,068 PF 1.33 | -$90 PF 0.97 |
| BB M5, 01–05 server, H1 trend | +$2,289 PF 1.37 | -$1,571 PF 0.74 |
| BB M5, 21–05 server, H1 trend | -$1,472 PF 0.84 | +$2,224 PF 1.23 |
Conclusion: the sign of every edge flips between periods → no robust edge; tuned params are curve-fit. Not tradeable.
Tooling gotcha: set files must list ALL inputs in declaration order (no duplicates) or MT5 silently drops overrides; generator = scratch mkset.py approach.
