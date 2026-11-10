GOLDEN TIME STRATEGY (18:45 PM Zone Breakout)
===============================================

File: GoldenTimeStrategy.mq5 (V5 - Optimized)

STRATEGY:
- Mark 3-min candle High/Low at 18:45 PM
- Wait for breakout/breakdown with candle close
- Enter on close, SL at zone opposite side (max 30 pips)
- TP1 = 50 pips (80% close), trail remainder at 3R
- Max 1 attempt per day
- Multi-TF trend filter (EMA 21/50 H1 + EMA 200 H4)
- ATR volatility filter

BEST BACKTEST (1 month, XAUUSD M5):
- Net Profit: +$305.20
- Win Rate: 53%
- Profit Factor: 1.28
- Max DD: 4.26%

2-YEAR RESULT: Strategy is net negative over 2 years.
Best used as a discretionary setup with manual confluence.

DEFAULT INPUTS (adjust ZoneHour for your broker's server time):
- ZoneHour = 13 (IST 18:45 = UTC+0 13:15)
- MaxSLPips = 30
- TP1Pips = 50
- TrailRR = 3.0
- MaxAttempts = 1
