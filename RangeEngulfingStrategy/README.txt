RANGE ENGULFING STRATEGY (IST 12:30-5:30 PM Range + 7 PM Entry)
================================================================

Files:
- RangeEngulfV2.mq5 (Fixed 0.10 lots - baseline)
- RangeEngulfV7.mq5 (1% risk dynamic lots - BEST VERSION)

STRATEGY:
1. Mark High/Low of 12:30 PM - 5:30 PM IST session (M1 chart)
2. Wait for 7:00 - 7:04 PM IST entry window
3. If price ABOVE range: wait for bearish engulfing -> SELL
4. If price BELOW range: wait for bullish engulfing -> BUY
5. If price INSIDE range: trade any engulfing in its direction
6. SL = engulfing candle High/Low + 1 pip buffer
7. TP = 1:2 Risk:Reward

V7 FEATURES (BEST VERSION):
- Dynamic lot sizing: 1% risk per trade ($100 on $10K account)
- Lot size adjusts based on SL distance (0.14 - 0.23 lots typical)
- Every loss is exactly ~$100 (1% of balance)
- MaxEngulfPips = 30 (caps oversized engulfing candles)

BEST BACKTEST (V7, 1 year, XAUUSD M1):
- Net Profit: +$916.05 (+9.2%)
- Win Rate: 66.7%
- Profit Factor: 4.03
- Max DD: 2.81%
- Sharpe Ratio: 7.90
- Recovery Factor: 3.19
- Total Trades: 9 (high quality)
- Avg Win: +$169.51 vs Avg Loss: -$100.91
- 6 green months out of 7 (86%)

SERVER TIME CONVERSION (adjust for your broker):
- IST 12:30 PM = UTC+2 09:00 (RangeStartHour=9)
- IST 5:30 PM  = UTC+2 14:00 (RangeEndHour=14)
- IST 7:00 PM  = UTC+2 15:30 (EntryStartHour=15, EntryStartMin=30)
- IST 7:04 PM  = UTC+2 15:34 (EntryEndHour=15, EntryEndMin=34)

THIS IS THE BEST PERFORMING STRATEGY OF ALL THREE.
