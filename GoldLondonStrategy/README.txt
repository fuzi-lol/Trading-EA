GOLD LONDON STRATEGY (1:5 RR - Lumen Trades)
==============================================

Files:
- GoldLondonStrategy.mq5 (V1 - Original)
- GoldLondonV3.mq5 (V3 - Best optimized version)

STRATEGY:
1. Mark 1H opening range at London open (High/Low)
2. Wait for liquidity grab (wick outside range, body closes inside)
3. Set bias (grab below = bullish, grab above = bearish)
4. Drop to M5, find Fair Value Gap (FVG) in bias direction
5. Enter on FVG retest
6. TP = range High/Low, SL = below/above FVG
7. Min 2:1 R:R enforced

BEST BACKTEST (V3, 2 years, XAUUSD M5):
- Net Profit: +$56.50
- Win Rate: 33.3%
- Profit Factor: 1.38
- Max DD: 0.66%
- Sharpe Ratio: 15.94
- Total Trades: 21 (very selective)
- Avg R:R achieved: 1:6.1

V3 OPTIMIZATIONS:
- Macro trend filter (H1 EMA 50 + Daily EMA 20)
- Only trades when trend aligns with liquidity grab
- Range width filter (8-60 pips)
- Sells dominate: 46.7% win rate, +$122

DEFAULT INPUTS:
- LondonOpenHour = 10 (UTC+2 server time)
- SessionEndHour = 16
- MinRR = 2.0
- FVG_Lookback = 30
- MinFVGPips = 3.0
