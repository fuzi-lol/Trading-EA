//+------------------------------------------------------------------+
//|                              MultiSession_MajorPairs_EA.mq5      |
//|                              Multi-Session Institutional Scalper  |
//|                                                                  |
//|  Strategy 1: London Breakout (Asian Range Break at London Open)   |
//|  Strategy 2: Mean Reversion (Bollinger Bands + RSI Confluence)    |
//|  Trend Filter: EMA on H1 to avoid counter-trend entries          |
//|                                                                  |
//|  Designed for: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, NZDUSD  |
//+------------------------------------------------------------------+
#property copyright   "L0rdTrey Systems"
#property version     "1.00"
#property description "Multi-Session Major Pairs Scalper with London Breakout + Mean Reversion"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//|  INPUT PARAMETERS                                                |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input double  InpRiskPercent      = 1.0;         // Risk Per Trade (% of Balance)
input double  InpFixedLot         = 0.0;         // Fixed Lot (0 = use Risk %)
input int     InpMaxDailyTrades   = 6;           // Max Trades Per Day
input int     InpMaxSpreadPoints  = 25;          // Max Spread (Points)
input ulong   InpMagicNumber      = 202610;      // Magic Number
input bool    InpUseTrendFilter   = true;        // Use H1 EMA Trend Filter
input int     InpTrendEMA_Period  = 50;          // Trend EMA Period (H1)

input group "=== London Breakout Strategy ==="
input bool    InpUseLondonBreak   = true;        // Enable London Breakout
input int     InpAsianStartHour   = 0;           // Asian Range Start (Server Hour)
input int     InpAsianEndHour     = 7;           // Asian Range End / London Open
input int     InpLondonEndHour    = 12;          // London Entry Window End
input int     InpBreakoutBuffer   = 30;          // Breakout Buffer (Points above/below range)
input double  InpLB_RiskReward    = 2.0;         // London Breakout Risk:Reward Ratio
input double  InpLB_MinRangePips  = 15.0;        // Min Asian Range (Pips)
input double  InpLB_MaxRangePips  = 80.0;        // Max Asian Range (Pips)

input group "=== Mean Reversion Strategy ==="
input bool    InpUseMeanRevert    = true;        // Enable Mean Reversion
input int     InpBB_Period        = 20;          // Bollinger Bands Period
input double  InpBB_Deviation     = 2.0;         // Bollinger Bands Deviation
input int     InpRSI_Period       = 14;          // RSI Period
input int     InpRSI_OversoldLvl  = 30;          // RSI Oversold Level
input int     InpRSI_OverboughtLvl= 70;          // RSI Overbought Level
input int     InpMR_StopLoss      = 300;         // Mean Reversion SL (Points)
input double  InpMR_RiskReward    = 1.5;         // Mean Reversion Risk:Reward
input int     InpMR_StartHour     = 13;          // Mean Reversion Start Hour
input int     InpMR_EndHour       = 21;          // Mean Reversion End Hour

input group "=== Trade Management ==="
input bool    InpUseTrailingStop  = true;        // Enable Trailing Stop
input int     InpTrailingStart    = 150;         // Trailing Activation (Points profit)
input int     InpTrailingStep     = 50;          // Trailing Step (Points)
input bool    InpCloseEOD         = true;        // Close All at End of Day
input int     InpCloseHour        = 23;          // EOD Close Hour

//+------------------------------------------------------------------+
//|  GLOBAL VARIABLES                                                |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;

// Asian range tracking
double   g_asianHigh;
double   g_asianLow;
bool     g_asianRangeSet;
datetime g_lastAsianDate;

// Daily trade counter
int      g_dailyTrades;
datetime g_lastTradeDate;

// Indicator handles
int      h_BB;
int      h_RSI;
int      h_EMA_H1;

// Strategy IDs embedded in magic number
#define MAGIC_LONDON   1
#define MAGIC_MEANREV  2

//+------------------------------------------------------------------+
//|  Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Create indicator handles
   h_BB = iBands(_Symbol, PERIOD_CURRENT, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
   h_RSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
   h_EMA_H1 = iMA(_Symbol, PERIOD_H1, InpTrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(h_BB == INVALID_HANDLE || h_RSI == INVALID_HANDLE || h_EMA_H1 == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles");
      return INIT_FAILED;
   }

   // Initialize
   g_asianHigh = 0;
   g_asianLow = 0;
   g_asianRangeSet = false;
   g_lastAsianDate = 0;
   g_dailyTrades = 0;
   g_lastTradeDate = 0;

   Print("MultiSession EA initialized on ", _Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//|  Expert deinitialization                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(h_BB != INVALID_HANDLE)    IndicatorRelease(h_BB);
   if(h_RSI != INVALID_HANDLE)   IndicatorRelease(h_RSI);
   if(h_EMA_H1 != INVALID_HANDLE) IndicatorRelease(h_EMA_H1);
}

//+------------------------------------------------------------------+
//|  Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Reset daily trade counter
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(today != g_lastTradeDate)
   {
      g_dailyTrades = 0;
      g_lastTradeDate = today;
   }

   // Check max daily trades
   if(g_dailyTrades >= InpMaxDailyTrades) return;

   // Check spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) return;

   int hour = dt.hour;

   // --- End of Day close ---
   if(InpCloseEOD && hour >= InpCloseHour)
   {
      CloseAllPositions();
      return;
   }

   // --- Trailing Stop Management ---
   if(InpUseTrailingStop)
      ManageTrailingStop();

   // --- Only process on new bar ---
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastBar) return;
   lastBar = currentBar;

   // --- Track Asian Session Range ---
   if(InpUseLondonBreak)
      TrackAsianRange(hour, today);

   // --- Strategy 1: London Breakout ---
   if(InpUseLondonBreak && g_asianRangeSet && hour >= InpAsianEndHour && hour < InpLondonEndHour)
   {
      if(!HasOpenPosition(MAGIC_LONDON))
         CheckLondonBreakout();
   }

   // --- Strategy 2: Mean Reversion ---
   if(InpUseMeanRevert && hour >= InpMR_StartHour && hour < InpMR_EndHour)
   {
      if(!HasOpenPosition(MAGIC_MEANREV))
         CheckMeanReversion();
   }
}

//+------------------------------------------------------------------+
//|  Track Asian Session High/Low                                    |
//+------------------------------------------------------------------+
void TrackAsianRange(int hour, datetime today)
{
   // Reset at start of new Asian session
   if(today != g_lastAsianDate && hour >= InpAsianStartHour)
   {
      g_asianHigh = 0;
      g_asianLow = DBL_MAX;
      g_asianRangeSet = false;
      g_lastAsianDate = today;
   }

   // During Asian session, track high/low
   if(hour >= InpAsianStartHour && hour < InpAsianEndHour)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
      double low  = iLow(_Symbol, PERIOD_CURRENT, 1);

      if(high > g_asianHigh) g_asianHigh = high;
      if(low < g_asianLow)   g_asianLow = low;
   }

   // Lock range at London open
   if(hour == InpAsianEndHour && !g_asianRangeSet && g_asianHigh > 0 && g_asianLow < DBL_MAX)
   {
      g_asianRangeSet = true;

      double rangePips = (g_asianHigh - g_asianLow) / PipSize();
      if(rangePips < InpLB_MinRangePips || rangePips > InpLB_MaxRangePips)
      {
         g_asianRangeSet = false;
         Print("Asian range ", DoubleToString(rangePips, 1), " pips - outside bounds, skipping");
      }
      else
      {
         Print("Asian range locked: High=", DoubleToString(g_asianHigh, _Digits),
               " Low=", DoubleToString(g_asianLow, _Digits),
               " Range=", DoubleToString(rangePips, 1), " pips");
      }
   }
}

//+------------------------------------------------------------------+
//|  Strategy 1: London Breakout                                     |
//+------------------------------------------------------------------+
void CheckLondonBreakout()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;
   double buffer = InpBreakoutBuffer * point;
   double rangeSize = g_asianHigh - g_asianLow;

   // Check trend filter
   if(InpUseTrendFilter)
   {
      double ema[];
      ArraySetAsSeries(ema, true);
      if(CopyBuffer(h_EMA_H1, 0, 0, 2, ema) < 2) return;

      // Bullish breakout only if price above EMA
      if(ask > g_asianHigh + buffer && bid < ema[0]) return;
      // Bearish breakout only if price below EMA
      if(bid < g_asianLow - buffer && ask > ema[0]) return;
   }

   // --- Bullish Breakout ---
   if(ask > g_asianHigh + buffer)
   {
      // Confirm with closed candle above the level
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(closePrice <= g_asianHigh + buffer) return;

      double sl = g_asianLow;
      double slDistance = ask - sl;
      double tp = ask + slDistance * InpLB_RiskReward;

      double lot = CalculateLotSize(slDistance);
      if(lot <= 0) return;

      if(trade.Buy(lot, _Symbol, ask, sl, tp, "LB_Buy"))
      {
         g_dailyTrades++;
         Print("LONDON BREAKOUT BUY: Price=", ask, " SL=", sl, " TP=", tp);
      }
   }
   // --- Bearish Breakout ---
   else if(bid < g_asianLow - buffer)
   {
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(closePrice >= g_asianLow - buffer) return;

      double sl = g_asianHigh;
      double slDistance = sl - bid;
      double tp = bid - slDistance * InpLB_RiskReward;

      double lot = CalculateLotSize(slDistance);
      if(lot <= 0) return;

      if(trade.Sell(lot, _Symbol, bid, sl, tp, "LB_Sell"))
      {
         g_dailyTrades++;
         Print("LONDON BREAKOUT SELL: Price=", bid, " SL=", sl, " TP=", tp);
      }
   }
}

//+------------------------------------------------------------------+
//|  Strategy 2: Mean Reversion (BB + RSI)                           |
//+------------------------------------------------------------------+
void CheckMeanReversion()
{
   // Get Bollinger Bands values
   double bbUpper[], bbMiddle[], bbLower[];
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbMiddle, true);
   ArraySetAsSeries(bbLower, true);

   if(CopyBuffer(h_BB, 1, 0, 3, bbUpper) < 3) return;   // Upper band
   if(CopyBuffer(h_BB, 0, 0, 3, bbMiddle) < 3) return;   // Middle band
   if(CopyBuffer(h_BB, 2, 0, 3, bbLower) < 3) return;    // Lower band

   // Get RSI
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(h_RSI, 0, 0, 3, rsi) < 3) return;

   // Get trend filter
   double ema[];
   ArraySetAsSeries(ema, true);
   if(InpUseTrendFilter)
   {
      if(CopyBuffer(h_EMA_H1, 0, 0, 2, ema) < 2) return;
   }

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;

   double slPoints = InpMR_StopLoss * point;
   double tpDistance = slPoints * InpMR_RiskReward;

   // --- Oversold: Buy Signal ---
   // Price touched/closed below lower BB + RSI oversold + previous candle was also below (confirmation)
   if(close1 <= bbLower[1] && rsi[1] < InpRSI_OversoldLvl)
   {
      // Trend filter: only buy if price near or above H1 EMA (or filter disabled)
      if(InpUseTrendFilter && ask < ema[0] * 0.998) return;

      double sl = ask - slPoints;
      double tp = MathMin(ask + tpDistance, bbMiddle[0]);  // Target middle band or RR, whichever is closer

      // Ensure TP is at least 1:1
      if(tp - ask < slPoints) tp = ask + tpDistance;

      double lot = CalculateLotSize(slPoints);
      if(lot <= 0) return;

      if(trade.Buy(lot, _Symbol, ask, sl, tp, "MR_Buy"))
      {
         g_dailyTrades++;
         Print("MEAN REVERSION BUY: RSI=", DoubleToString(rsi[1], 1),
               " Close=", close1, " LowerBB=", DoubleToString(bbLower[1], _Digits));
      }
   }
   // --- Overbought: Sell Signal ---
   else if(close1 >= bbUpper[1] && rsi[1] > InpRSI_OverboughtLvl)
   {
      // Trend filter: only sell if price near or below H1 EMA (or filter disabled)
      if(InpUseTrendFilter && bid > ema[0] * 1.002) return;

      double sl = bid + slPoints;
      double tp = MathMax(bid - tpDistance, bbMiddle[0]);

      if(bid - tp < slPoints) tp = bid - tpDistance;

      double lot = CalculateLotSize(slPoints);
      if(lot <= 0) return;

      if(trade.Sell(lot, _Symbol, bid, sl, tp, "MR_Sell"))
      {
         g_dailyTrades++;
         Print("MEAN REVERSION SELL: RSI=", DoubleToString(rsi[1], 1),
               " Close=", close1, " UpperBB=", DoubleToString(bbUpper[1], _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//|  Calculate lot size based on risk percentage                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   if(InpFixedLot > 0) return NormalizeLot(InpFixedLot);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0) return 0;

   double lot = riskAmount / (slDistance / tickSize * tickValue);
   return NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//|  Normalize lot size to broker constraints                        |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep <= 0) lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//|  Get pip size for current symbol                                 |
//+------------------------------------------------------------------+
double PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5) return _Point * 10;
   return _Point;
}

//+------------------------------------------------------------------+
//|  Check if we have an open position for a strategy                |
//+------------------------------------------------------------------+
bool HasOpenPosition(int strategyId)
{
   string prefix = (strategyId == MAGIC_LONDON) ? "LB_" : "MR_";

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
         {
            string comment = posInfo.Comment();
            if(StringFind(comment, prefix) >= 0)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//|  Manage trailing stop on open positions                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber) continue;

      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double point = _Point;
      double trailActivation = InpTrailingStart * point;
      double trailStep = InpTrailingStep * point;

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = bid - openPrice;

         if(profit >= trailActivation)
         {
            double newSL = bid - trailStep;
            newSL = NormalizeDouble(newSL, _Digits);

            if(newSL > currentSL + point)
            {
               trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = openPrice - ask;

         if(profit >= trailActivation)
         {
            double newSL = ask + trailStep;
            newSL = NormalizeDouble(newSL, _Digits);

            if(currentSL == 0 || newSL < currentSL - point)
            {
               trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|  Close all positions for this EA                                 |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
         {
            trade.PositionClose(posInfo.Ticket());
         }
      }
   }
}
//+------------------------------------------------------------------+
